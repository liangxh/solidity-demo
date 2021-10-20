// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract Coin {

    address public minter;
    mapping (address => uint) public balances;

    // Event, 透过 emit 触发, 由 watch 捕捉
    event Sent(address from, address to, uint amount);

    // Constructor code is only run when the contract
    constructor() {
        minter = msg.sender;
    }

    function mint(address receiver, uint amount) public {
        // 使用 require 检查条件, 失败的话会 revert，没有报警信息
        // require(msg.sender == minter);
        require(
            msg.sender == minter,
            "Only minter can mint"
        );

        // 核心内容
        balances[receiver] += amount;
    }

    // error 声明，透过 revert 触发
    error InsufficientBalance(uint requested, uint available);

    function send(address receiver, uint amount) public {
        if (amount > balances[msg.sender])
            // 声用 revert 和错误类型
            revert InsufficientBalance({
                requested: amount,
                available: balances[msg.sender]
            });

        balances[msg.sender] -= amount;
        balances[receiver] += amount;

        // 触发 Event
        emit Sent(msg.sender, receiver, amount);
    }

    function minter() external view returns (address) { return minter; }

    function balances(address _account) external view returns (uint) { return balances[_account]; }

    // js 中对 Event 监听
    /*Coin.Sent().watch({}, '', function(error, result) {
        if (!error) {
            console.log("Coin transfer: " + result.args.amount +
                " coins were sent from " + result.args.from +
                " to " + result.args.to + ".");
            console.log("Balances now:\n" +
                "Sender: " + Coin.balances.call(result.args.from) +
                "Receiver: " + Coin.balances.call(result.args.to));
        }
    })*/
}
