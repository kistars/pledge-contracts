// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./multiSignatureClient.sol";

library whiteListAdress {
    function addWhiteListAddress(address[] storage whiteList, address temp) internal {
        if (!isEligibleAddress(whiteList, temp)) {
            whiteList.push(temp);
        }
    }

    function removeWhiteListAddress(address[] storage whiteList, address temp) internal returns (bool) {
        uint256 len = whiteList.length;
        uint256 i = 0;

        for (; i < len; i++) {
            if (whiteList[i] == temp) {
                break;
            }
        }

        if (i < len) {
            if (i != len - 1) {
                whiteList[i] = whiteList[len - 1];
            }
            whiteList.pop();
            return true;
        }
        return false;
    }

    function isEligibleAddress(address[] memory whiteList, address temp) internal pure returns (bool) {
        uint256 len = whiteList.length;
        for (uint256 i = 0; i < len; i++) {
            if (whiteList[i] == temp) {
                return true;
            }
        }
        return false;
    }
}

contract multiSignature is multiSignatureClient {
    uint256 private constant _defaultIndex = 0;

    using whiteListAdress for address[];

    address[] public signatureOwners; // 保存多签账户地址
    uint256 public threshold;

    struct signatureInfo {
        address applicant; // 调用方
        address[] signatures; // 白名单地址
    }

    // [key] = hash(调用方，被调用合约)
    mapping(bytes32 => signatureInfo[]) public signatureMap;

    event TransferOwner(address indexed sender, address indexed oldOwner, address indexed newOwner);
    event CreateApplication(address indexed from, address indexed to, bytes32 indexed msgHash);
    event SignApplication(address indexed from, bytes32 indexed msgHash, uint256 index);
    event RevokeApplication(address indexed from, bytes32 indexed msgHash, uint256 index);

    modifier onlyOwner() {
        require(signatureOwners.isEligibleAddress(msg.sender), "Multiple Signature : caller is not in the ownerList!");
        _;
    }

    modifier validIndex(bytes32 msghash, uint256 index) {
        require(index < signatureMap[msghash].length, "Multiple Signature : Message index is overflow!");
        _;
    }

    constructor(address[] memory _owners, uint256 _limitedSignNum) multiSignatureClient(address(this)) {
        require(
            _owners.length >= _limitedSignNum,
            "Multiple Signature : Signature threshold is greater than owners' length!"
        );

        signatureOwners = _owners; // 初始化多签账户地址
        threshold = _limitedSignNum; // 签名数量阈值
    }

    // 修改多签账户地址
    function transferOwner(uint256 _index, address _newOwner) public onlyOwner validCall {
        require(_index < signatureOwners.length, "Multiple Signature: Owner index is overflow");
        emit TransferOwner(msg.sender, signatureOwners[_index], _newOwner);
        signatureOwners[_index] = _newOwner;
    }

    /// @param to 被调用的合约地址
    function createApplication(address to) external returns (uint256) {
        bytes32 msghash = getApplicationHash(msg.sender, to);
        uint256 index = signatureMap[msghash].length;
        signatureMap[msghash].push(signatureInfo(msg.sender, new address[](0)));
        emit CreateApplication(msg.sender, to, msghash);
        return index;
    }

    // 加入白名单
    function signApplication(bytes32 msghash) external onlyOwner validIndex(msghash, _defaultIndex) {
        emit SignApplication(msg.sender, msghash, _defaultIndex);
        signatureMap[msghash][_defaultIndex].signatures.addWhiteListAddress(msg.sender);
    }

    // 移除白名单
    function revokeSignApplication(bytes32 msghash) external onlyOwner validIndex(msghash, _defaultIndex) {
        emit SignApplication(msg.sender, msghash, _defaultIndex);
        signatureMap[msghash][_defaultIndex].signatures.removeWhiteListAddress(msg.sender);
    }

    //
    function getValidSignature(bytes32 msghash, uint256 lastIndex) external view returns (uint256) {
        signatureInfo[] storage info = signatureMap[msghash];
        for (uint256 i = lastIndex; i < info.length; i++) {
            if (info[i].signatures.length >= threshold) {
                return i + 1;
            }
        }
        return 0;
    }

    function getApplicationInfo(bytes32 msghash, uint256 index)
        public
        view
        validIndex(msghash, index)
        returns (address, address[] memory)
    {
        signatureInfo memory info = signatureMap[msghash][index];
        return (info.applicant, info.signatures);
    }

    function getApplicationCount(bytes32 msghash) public view returns (uint256) {
        return signatureMap[msghash].length;
    }

    function getApplicationHash(address from, address to) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(from, to));
    }
}
