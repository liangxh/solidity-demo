// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract BlindAuction {
    struct Bid {
        bytes32 blindedBid;
        uint deposit;
    }

    address payable public beneficiary;
    uint public biddingEnd;    // bidding 结束时间
    uint public revealEnd;     //
    bool public ended;         // 是否已结束

    mapping(address => Bid[]) public bids;

    address public highestBidder;
    uint public highestBid;

    // Allowed withdrawals of previous bids
    mapping(address => uint) pendingReturns;

    event AuctionEnded(address winner, uint highestBid);

    // Errors
    /// 太早了, 需要在 time 后
    error TooEarly(uint time);
    /// 太晚了, 需要在 time 前
    error TooLate(uint time);
        /// auctionEnd 已被调用
    error AuctionEndAlreadyCalled();

    // Modifiers, 相当于装饰器
    // `_` 表示原本的函数体
    modifier onlyBefore(uint time) {
        if (block.timestamp >= time) revert TooLate(time);
        _;
    }
    modifier onlyAfter(uint time) {
        if (block.timestamp <= time) revert TooEarly(time);
        _;
    }

    constructor(uint biddingTime, uint revealTime, address payable beneficiaryAddress) {
        // 收益接收者
        beneficiary = beneficiaryAddress;
        // 竞标结束时间
        biddingEnd = block.timestamp + biddingTime;
        // 竞标结果公布时间
        revealEnd = biddingEnd + revealTime;
    }

    /// 提交竞标
    function bid(bytes32 blindedBid) external payable onlyBefore(biddingEnd) {
        bids[msg.sender].push(Bid({
            blindedBid: blindedBid,
            deposit: msg.value
        }));
    }

    /// Reveal 最高竞价以外的 blinded bids
    function reveal(uint[] calldata values, bool[] calldata fakes, bytes32[] calldata secrets)
            external onlyAfter(biddingEnd) onlyBefore(revealEnd) {
        uint length = bids[msg.sender].length;
        require(values.length == length);
        require(fakes.length == length);
        require(secrets.length == length);

        uint refund;
        for (uint i = 0; i < length; i++) {
            // 获取之前提交的 bid 信息
            Bid storage bidToCheck = bids[msg.sender][i];
            (uint value, bool fake, bytes32 secret) = (values[i], fakes[i], secrets[i]);

            // 故意传错的话可以废弃该竞价，但当初付的不能续回
            if (bidToCheck.blindedBid != keccak256(abi.encodePacked(value, fake, secret))) {
                continue;
            }
            // 累加续回款
            refund += bidToCheck.deposit;
            // 真的 && 当时付的钱 >= hash 里原本的 value
            // 这是设计来混淆其他 bidder 的
            // 可以设置 fake=false, 高 deposit 但低 value 可以抬价
            // 可以设置 fake=true,  高 deposit 来抬价
            // 可以设置 fake=true,  低 deposit, 智在参與？
            if (!fake && bidToCheck.deposit >= value) {
                // value 才是真正的竞价
                if (placeBid(msg.sender, value))
                    // value 的部分参与竞价, 得留着
                    refund -= value;
                // 如果反复竞价，被抵掉的会记录到 pendingReturns, 需要另外调 withdraw
            }
            // else 如果是 fake 或者当时付的钱 < hash 里原本的 value, 实际上没参与竞标

            // 消除这个字段，前面的检查不会被重复查看
            bidToCheck.blindedBid = bytes32(0);
        }
        // 返还
        payable(msg.sender).transfer(refund);
    }

    // biddingEnd 之后的 reveal 阶段才会叠加 pendingReturns
    // 在 reveal 中，自己在竞价历史上的多次到达最高价就会累加到 pendingReturns
    // 在自己 reveal 之后别人 reveal 可能把自己的最高价抵掉，再加一次 pendingReturns
    function withdraw() external {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            payable(msg.sender).transfer(amount);
        }
    }

    // 结束竞标
    function auctionEnd() external onlyAfter(revealEnd) {
        // 检查未触发过
        if (ended) revert AuctionEndAlreadyCalled();
        emit AuctionEnded(highestBidder, highestBid);
        ended = true;
        // 向受益者支付
        beneficiary.transfer(highestBid);
    }

    // internal 函数相当于 private
    function placeBid(address bidder, uint value) internal returns (bool success) {
        // 要比当前最高的更高
        if (value <= highestBid) return false;
        // 把原本最高的加到待返还
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }
        // 更新最高竞价记录
        highestBid = value;
        highestBidder = bidder;
        return true;
    }
}
