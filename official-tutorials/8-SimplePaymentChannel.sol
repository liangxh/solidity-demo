// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract SimplePaymentChannel {
    address payable public sender;
    address payable public recipient;
    uint256 public expiration;

    constructor (address payable recipientAddress, uint256 duration) payable {
        // 付款人即合约创建人
        sender = payable(msg.sender);
        // 收款人
        recipient = recipientAddress;
        // 合约结束时间
        expiration = block.timestamp + duration;
    }

    function close(uint256 amount, bytes memory signature) external {
        // 限收款人触发
        require(msg.sender == recipient);
        // 校验签名
        require(isValidSignature(amount, signature));
        // 向收款人转账
        recipient.transfer(amount);
        // 完成即结束合约，退回合约余额
        selfdestruct(sender);
    }

    /// 付款人延长合约结束时间
    function extend(uint256 newExpiration) external {
        require(msg.sender == sender);
        require(newExpiration > expiration);

        expiration = newExpiration;
    }

    /// 只要超时了就可以触发, 谁触发都行
    function claimTimeout() external {
        require(block.timestamp >= expiration);
        selfdestruct(sender);
    }

    // 以下均可参考 7-ReceiverPays.sol 的注释
    /// 检查是否签名是否由合约创建者签署
    function isValidSignature(uint256 amount, bytes memory signature) internal view returns (bool) {
        bytes32 message = prefixed(keccak256(abi.encodePacked(this, amount)));
        return recoverSigner(message, signature) == sender;
    }

    function splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(sig.length == 65);
        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
        return (v, r, s);
    }

    function recoverSigner(bytes32 message, bytes memory sig) internal pure returns (address) {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);
        return ecrecover(message, v, r, s);
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}
