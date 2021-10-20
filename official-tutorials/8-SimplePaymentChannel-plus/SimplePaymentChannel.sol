// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./SignRecover.sol";

contract SimplePaymentChannel {
    using SignRecover for address;

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
        require(address(this).recover(amount, signature) == sender);
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
}
