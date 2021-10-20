// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

// 支持 A 对 B 承诺的支付，但触发权给 B
contract ReceiverPays {
    address owner = msg.sender;
    mapping(uint256 => bool) usedNonces;

    // 在创建时支付的费用要能支持接下来准备的转账
    constructor() payable {}

    function claimPayment(uint256 amount, uint256 nonce, bytes memory signature) external {
        // 一个 nonce 只可用一次, 如果下面 require 验证失败的话标记不会被 revert
        require(!usedNonces[nonce]);
        usedNonces[nonce] = true;

        // 消息组成
        // - 收款人: 对应 msg.sender
        // - 转账金额: 对应 amount
        // - nonce: 为了避免此合约下相同的 （收款人，转账金额）被 replay attack
        // - contract address: 避免跨合约 replay attack
        bytes32 message = prefixed(keccak256(abi.encodePacked(msg.sender, amount, nonce, this)));
        // 确认此 message 的签名是合约是创建人
        require(recoverSigner(message, signature) == owner);

        payable(msg.sender).transfer(amount);
    }

    /// 结束合约，取回余额
    function shutdown() external {
        require(msg.sender == owner);
        selfdestruct(payable(msg.sender));
    }

    /// ECDSA 本身保含 r,s 两部分，以太坊的签名加入了 v 以验证消息发送者
    function splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(sig.length == 65);
        assembly {
            // first 32 bytes, after the length prefix.
            r := mload(add(sig, 32))
            // second 32 bytes.
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes).
            v := byte(0, mload(add(sig, 96)))
        }
        return (v, r, s);
    }

    /// 原生的 ecrecover 可以解析出 messaage 本身的发送者
    function recoverSigner(bytes32 message, bytes memory sig) internal pure returns (address) {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);
        return ecrecover(message, v, r, s);
    }

    /// 为了模仿 eth_sign 添加前缀
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}
