// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../library/SafeTransfer.sol";
import "../interface/IDebtToken.sol";
import "../interface/IBscPledgeOracle.sol";
import "../interface/IUniswapV2Router02.sol";
import "../multiSignature/multiSignatureClient.sol";

contract PledgePool is ReentrancyGuard, SafeTransfer, multiSignatureClient {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // default decimal
    uint256 internal constant calDecimal = 1e18;
    // Based on the decimal of the commission and interest
    uint256 internal constant baseDecimal = 1e8;
    uint256 public minAmount = 100e18;
    // one years
    uint256 constant baseYear = 365 days;

    enum PoolState {
        MATCH,
        EXECUTION,
        FINISH,
        LIQUIDATION,
        UNDONE
    }

    PoolState constant defaultChoice = PoolState.MATCH;

    bool public globalPaused = false;
    // pancake swap router
    address public swapRouter;
    // receiving fee address
    address payable public feeAddress;
    // oracle address
    IBscPledgeOracle public oracle;
    // fee
    uint256 public lendFee;
    uint256 public borrowFee;

    // pool base info
    struct PoolBaseInfo {
        uint256 settleTime; // 结算时间
        uint256 endTime; // 结束时间
        uint256 interestRate; // 池的固定利率，单位是1e8 (1e8)
        uint256 maxSupply; // 池的最大限额
        uint256 lendSupply; // 当前实际存款的借款
        uint256 borrowSupply; // 当前实际存款的借款
        uint256 martgageRate; // 池的抵押率，单位是1e8 (1e8)
        address lendToken; // 出借方代币地址 (比如 BUSD..)
        address borrowToken; // 借款方代币地址 (比如 BTC..)
        PoolState state; // 状态 'MATCH, EXECUTION, FINISH, LIQUIDATION, UNDONE'
        IDebtToken spCoin; // sp_token的erc20地址 (比如 spBUSD_1..)
        IDebtToken jpCoin; // jp_token的erc20地址 (比如 jpBTC_1..)
        uint256 autoLiquidateThreshold; // 自动清算阈值 (触发清算阈值
    }

    // total base info
    PoolBaseInfo[] public poolBaseInfo;

    // 每个池的数据信息
    struct PoolDataInfo {
        uint256 settleAmountLend; // 结算时的实际出借金额
        uint256 settleAmountBorrow; // 结算时的实际借款金额
        uint256 finishAmountLend; // 完成时的实际出借金额
        uint256 finishAmountBorrow; // 完成时的实际借款金额
        uint256 liquidationAmounLend; // 清算时的实际出借金额
        uint256 liquidationAmounBorrow; // 清算时的实际借款金额
    }

    // total data pool
    PoolDataInfo[] public poolDataInfo;

    // 借款用户信息
    struct BorrowInfo {
        uint256 stakeAmount; // 当前借款的质押金额
        uint256 refundAmount; // 多余的退款金额
        bool hasNoRefund; // 默认为false，false = 未退款，true = 已退款
        bool hasNoClaim; // 默认为false，false = 未认领，true = 已认领
    }

    // Info of each user that stakes tokens.  {user.address : {pool.index : user.borrowInfo}}
    mapping(address => mapping(uint256 => BorrowInfo)) public userBorrowInfo;

    // 出借用户信息
    struct LendInfo {
        uint256 stakeAmount; // 当前借款的质押金额
        uint256 refundAmount; // 超额退款金额
        bool hasNoRefund; // 默认为false，false = 无退款，true = 已退款
        bool hasNoClaim; // 默认为false，false = 无索赔，true = 已索赔
    }

    // Info of each user that stakes tokens.  {user.address : {pool.index : user.lendInfo}}
    mapping(address => mapping(uint256 => LendInfo)) public userLendInfo;

    // 事件
    // 存款借出事件，from是借出者地址，token是借出的代币地址，amount是借出的数量，mintAmount是生成的数量
    event DepositLend(address indexed from, address indexed token, uint256 amount, uint256 mintAmount);
    // 借出退款事件，from是退款者地址，token是退款的代币地址，refund是退款的数量
    event RefundLend(address indexed from, address indexed token, uint256 refund);
    // 借出索赔事件，from是索赔者地址，token是索赔的代币地址，amount是索赔的数量
    event ClaimLend(address indexed from, address indexed token, uint256 amount);
    // 提取借出事件，from是提取者地址，token是提取的代币地址，amount是提取的数量，burnAmount是销毁的数量
    event WithdrawLend(address indexed from, address indexed token, uint256 amount, uint256 burnAmount);
    // 存款借入事件，from是借入者地址，token是借入的代币地址，amount是借入的数量，mintAmount是生成的数量
    event DepositBorrow(address indexed from, address indexed token, uint256 amount, uint256 mintAmount);
    // 借入退款事件，from是退款者地址，token是退款的代币地址，refund是退款的数量
    event RefundBorrow(address indexed from, address indexed token, uint256 refund);
    // 借入索赔事件，from是索赔者地址，token是索赔的代币地址，amount是索赔的数量
    event ClaimBorrow(address indexed from, address indexed token, uint256 amount);
    // 提取借入事件，from是提取者地址，token是提取的代币地址，amount是提取的数量，burnAmount是销毁的数量
    event WithdrawBorrow(address indexed from, address indexed token, uint256 amount, uint256 burnAmount);
    // 交换事件，fromCoin是交换前的币种地址，toCoin是交换后的币种地址，fromValue是交换前的数量，toValue是交换后的数量
    event Swap(address indexed fromCoin, address indexed toCoin, uint256 fromValue, uint256 toValue);
    // 紧急借入提取事件，from是提取者地址，token是提取的代币地址，amount是提取的数量
    event EmergencyBorrowWithdrawal(address indexed from, address indexed token, uint256 amount);
    // 紧急借出提取事件，from是提取者地址，token是提取的代币地址，amount是提取的数量
    event EmergencyLendWithdrawal(address indexed from, address indexed token, uint256 amount);
    // 状态改变事件，pid是项目id，beforeState是改变前的状态，afterState是改变后的状态
    event StateChange(uint256 indexed pid, uint256 indexed beforeState, uint256 indexed afterState);
    // 设置费用事件，newLendFee是新的借出费用，newBorrowFee是新的借入费用
    event SetFee(uint256 indexed newLendFee, uint256 indexed newBorrowFee);
    // 设置交换路由器地址事件，oldSwapAddress是旧的交换地址，newSwapAddress是新的交换地址
    event SetSwapRouterAddress(address indexed oldSwapAddress, address indexed newSwapAddress);
    // 设置费用地址事件，oldFeeAddress是旧的费用地址，newFeeAddress是新的费用地址
    event SetFeeAddress(address indexed oldFeeAddress, address indexed newFeeAddress);
    // 设置最小数量事件，oldMinAmount是旧的最小数量，newMinAmount是新的最小数量
    event SetMinAmount(uint256 indexed oldMinAmount, uint256 indexed newMinAmount);

    /// @param _oracle 预言机合约地址
    /// @param _swapRouter 交易代币合约地址
    /// @param _feeAddress 手续费合约地址
    /// @param _multiSignature 多签验证合约地址
    constructor(address _oracle, address _swapRouter, address payable _feeAddress, address _multiSignature)
        multiSignatureClient(_multiSignature)
    {
        require(_oracle != address(0), "oracle is zero address");
        require(_swapRouter != address(0), "swapRouter is zero address");
        require(_feeAddress != address(0), "feeAddress is zero address");

        oracle = IBscPledgeOracle(_oracle);
        swapRouter = _swapRouter;
        feeAddress = _feeAddress;
        lendFee = 0;
        borrowFee = 0;
    }

    function setFee(uint256 _lendFee, uint256 _borrowFee) external validCall {
        lendFee = _lendFee;
        borrowFee = _borrowFee;
        emit SetFee(_lendFee, _borrowFee);
    }

    //
    function setSwapRouterAddress(address _swapRouter) external validCall {
        require(_swapRouter != address(0), "swapRouter is zero address");
        emit SetSwapRouterAddress(swapRouter, _swapRouter);
        swapRouter = _swapRouter;
    }

    /**
     * @dev Set up the address to receive the handling fee
     * @notice Only allow administrators to operate
     */
    function setFeeAddress(address payable _feeAddress) external validCall {
        require(_feeAddress != address(0), "Is zero address");
        emit SetFeeAddress(feeAddress, _feeAddress);
        feeAddress = _feeAddress;
    }

    /**
     * @dev Set the min amount
     */
    function setMinAmount(uint256 _minAmount) external validCall {
        emit SetMinAmount(minAmount, _minAmount);
        minAmount = _minAmount;
    }

    /**
     * @dev Query pool length
     */
    function poolLength() external view returns (uint256) {
        return poolBaseInfo.length;
    }

    /**
     * @dev 创建一个新的借贷池。函数接收一系列参数，包括结算时间、结束时间、利率、最大供应量、抵押率、借款代币、借出代币、SP代币、JP代币和自动清算阈值。
     *  Can only be called by the owner.
     */
    function createPoolInfo(
        uint256 _settleTime,
        uint256 _endTime,
        uint64 _interestRate,
        uint256 _maxSupply,
        uint256 _martgageRate,
        address _lendToken,
        address _borrowToken,
        address _spToken,
        address _jpToken,
        uint256 _autoLiquidateThreshold
    ) public validCall {
        // 检查是否已设置token ...
        // 需要结束时间大于结算时间
        require(_endTime > _settleTime, "createPool:end time grate than settle time");
        // 需要_jpToken不是零地址
        require(_jpToken != address(0), "createPool:is zero address");
        // 需要_spToken不是零地址
        require(_spToken != address(0), "createPool:is zero address");

        // 创建基础池信息结构体
        PoolBaseInfo memory newPool = _createPoolBaseInfo(
            _settleTime,
            _endTime,
            _interestRate,
            _maxSupply,
            _martgageRate,
            _lendToken,
            _borrowToken,
            _spToken,
            _jpToken,
            _autoLiquidateThreshold
        );

        // 推入基础池信息
        poolBaseInfo.push(newPool);

        PoolDataInfo memory newPoolData = _createPoolDataInfo(0, 0, 0, 0, 0, 0);
        // 推入池数据信息
        poolDataInfo.push(newPoolData);
    }

    /**
     * @dev 创建池基础信息的内部函数，用于避免栈深度超限
     */
    function _createPoolBaseInfo(
        uint256 _settleTime,
        uint256 _endTime,
        uint64 _interestRate,
        uint256 _maxSupply,
        uint256 _martgageRate,
        address _lendToken,
        address _borrowToken,
        address _spToken,
        address _jpToken,
        uint256 _autoLiquidateThreshold
    ) internal pure returns (PoolBaseInfo memory) {
        return PoolBaseInfo({
            settleTime: _settleTime,
            endTime: _endTime,
            interestRate: _interestRate,
            maxSupply: _maxSupply,
            lendSupply: 0,
            borrowSupply: 0,
            martgageRate: _martgageRate,
            lendToken: _lendToken,
            borrowToken: _borrowToken,
            state: defaultChoice,
            spCoin: IDebtToken(_spToken),
            jpCoin: IDebtToken(_jpToken),
            autoLiquidateThreshold: _autoLiquidateThreshold
        });
    }

    /**
     * @dev 创建池数据信息的内部函数，用于避免栈深度超限
     */
    function _createPoolDataInfo(
        uint256 _settleAmountLend,
        uint256 _settleAmountBorrow,
        uint256 _finishAmountLend,
        uint256 _finishAmountBorrow,
        uint256 _liquidationAmounLend,
        uint256 _liquidationAmounBorrow
    ) internal pure returns (PoolDataInfo memory) {
        return PoolDataInfo({
            settleAmountLend: _settleAmountLend,
            settleAmountBorrow: _settleAmountBorrow,
            finishAmountLend: _finishAmountLend,
            finishAmountBorrow: _finishAmountBorrow,
            liquidationAmounLend: _liquidationAmounLend,
            liquidationAmounBorrow: _liquidationAmounBorrow
        });
    }
}
