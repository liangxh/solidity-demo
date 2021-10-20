// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract Purchase {
    uint public value;
    address payable public seller;
    address payable public buyer;

    enum State { Created, Locked, Release, Inactive }
    // enum 实例的初始值为 enum 的第一个值
    State public state;

    modifier condition(bool condition_) {
        require(condition_);
        _;
    }

    // Errors
    /// 只有买家可以调用
    error OnlyBuyer();
    /// 只有卖家可以调用
    error OnlySeller();
    /// 在现阶段不可以调用
    error InvalidState();
    /// 数值不是偶数
    error ValueNotEven();

    modifier onlyBuyer() {
        if (msg.sender != buyer) revert OnlyBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller) revert OnlySeller();
        _;
    }

    modifier inState(State state_) {
        if (state != state_) revert InvalidState();
        _;
    }

    event Aborted();
    event PurchaseConfirmed();
    event ItemReceived();
    event SellerRefunded();

    constructor() payable {
        seller = payable(msg.sender);
        // 确认价格为偶数
        value = msg.value / 2;
        if ((2 * value) != msg.value)
            revert ValueNotEven();
    }

    /// 取消交易并取回币
    function abort() external onlySeller inState(State.Created) {
        emit Aborted();
        // 注意此处先改 state 再转钱
        // 转钱貌似要注意 reentrancy-safe, 都要先做前置判断
        state = State.Inactive;
        seller.transfer(address(this).balance);
    }

    /// 买家下单
    function confirmPurchase() external
        inState(State.Created) condition(msg.value == (2 * value))
        payable
    {
        emit PurchaseConfirmed();
        buyer = payable(msg.sender);
        // 更新狀态
        state = State.Locked;
    }

    /// 买家确认到货
    function confirmReceived() external onlyBuyer inState(State.Locked) {
        emit ItemReceived();
        // 先改 state 后转钱
        state = State.Release;
        buyer.transfer(value);
    }

    /// 交易结束，卖家取回抵押和
    function refundSeller() external onlySeller inState(State.Release) {
        emit SellerRefunded();
        // 先改 state 后转钱
        state = State.Inactive;
        seller.transfer(3 * value);
    }
}