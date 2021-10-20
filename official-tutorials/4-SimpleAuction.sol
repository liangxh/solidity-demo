// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract SimpleAuction {
    address payable public beneficiary;
    uint public auctionEndTime;

    address public highestBidder;
    uint public highestBid;

    // Allowed withdrawals of previous bids
    mapping(address => uint) pendingReturns;
    // 初始值 false
    bool ended;

    // Events
    /// 更新最高竞价
    event HighestBidIncreased(address bidder, uint amount);
    /// 竞标结束
    event AuctionEnded(address winner, uint amount);

    // Errors
    /// 竞标结束 / The auction has already ended.
    error AuctionAlreadyEnded();
    /// 已有更高竞价 / There is already a higher or equal bid.
    error BidNotHighEnough(uint highestBid);
    /// auction 未结束 / The auction has not ended yet.
    error AuctionNotYetEnded();
    /// auctionEnd 已被调用 / he function auctionEnd has already been called.
    error AuctionEndAlreadyCalled();

    constructor(uint biddingTime, address payable beneficiaryAddress) {
        beneficiary = beneficiaryAddress;
        auctionEndTime = block.timestamp + biddingTime;
    }

    function bid() external payable {
        // auction 已结束
        if (block.timestamp > auctionEndTime)
            revert AuctionAlreadyEnded();
        // 已有更高竞价
        if (msg.value <= highestBid)
            revert BidNotHighEnough(highestBid);
        // 记录将要返还的原本的最高竞价
        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    // 赎回失败的竞标
    function withdraw() external returns (bool) {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            // 先清零记录避免用户重复调用
            pendingReturns[msg.sender] = 0;
            if (!payable(msg.sender).send(amount)) {
                // 转账失败, 只恢复记录
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    /// 竞标结束
    function auctionEnd() external {
        // 1. Conditions：checking conditions
        if (block.timestamp < auctionEndTime)
            revert AuctionNotYetEnded();
        if (ended)
            revert AuctionEndAlreadyCalled();

        // 2. Effects performing actions (potentially changing conditions)
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        // 3. Interaction
        beneficiary.transfer(highestBid);
    }
}