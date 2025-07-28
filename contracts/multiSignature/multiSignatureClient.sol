// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMultiSignature {
    function getValidSignature(bytes32 msghash, uint256 lastIndex) external view returns (uint256);
}

contract multiSignatureClient {
    uint256 private constant _multiSignaturePosition = uint256(keccak256("org.multiSignature.storage"));
    uint256 private constant _defaultIndex = 0;

    constructor(address _multiSignature) {
        require(_multiSignature != address(0), "multiSignatureClient: Multiple signature contract address is zero!");
        saveValue(_multiSignaturePosition, uint256(uint160(_multiSignature)));
    }

    modifier validCall() {
        checkMultiSignature();
        _;
    }

    function checkMultiSignature() internal view {
        uint256 value;
        assembly {
            value := callvalue()
        }

        bytes32 msgHash = keccak256(abi.encodePacked(msg.sender, address(this)));
        address multiSign = getMultiSignatureAddress();
        uint256 newIndex = IMultiSignature(multiSign).getValidSignature(msgHash, _defaultIndex);
        require(newIndex > _defaultIndex, "multiSignatureClient : This tx is not aprroved");
    }

    function saveValue(uint256 _position, uint256 _value) internal {
        assembly {
            sstore(_position, _value)
        }
    }

    // 多签合约地址
    function getMultiSignatureAddress() public view returns (address) {
        return address(uint160(getValue(_multiSignaturePosition)));
    }

    function getValue(uint256 _position) internal view returns (uint256 value) {
        assembly {
            value := sload(_position)
        }
    }
}
