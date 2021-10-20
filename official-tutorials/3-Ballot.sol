// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Ballot {
    // struct 声明
    struct Voter {
        uint weight;      // weight is accumulated by delegation
        bool voted;       // if true, that person already voted
        address delegate; // person delegated to
        uint vote;        // index of the voted proposal
    }

    struct Proposal {
        bytes32 name;
        uint voteCount;
    }

    address public chairperson;
    Proposal[] public proposals;               // list
    mapping(address => Voter) public voters;   // map

    /*constructor(bytes32[] memory proposalNames) {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;

        for (uint i = 0; i < proposalNames.length; i++) {
            proposals.push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }*/

    constructor() {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;
    }

    function addProposal(string memory name) external returns (bytes32 ret)
    {
        bytes memory tmp = bytes(name);
        require(tmp.length > 0, "empty name");
        assembly {
            ret := mload(add(name, 32))
        }

        proposals.push(Proposal({
            name: ret,
            voteCount: 0
        }));
    }

    function giveRightToVote(address voter) external {
        require(msg.sender == chairperson, "Only chairperson can give right to vote.");
        require(! voters[voter].voted,     "The voter already voted.");
        require(voters[voter].weight == 0, "The voter has not weight");

        voters[voter].weight = 1;
    }

    function delegate(address to) external {
        require(to != msg.sender, "Self-delegation is disallowed.");

        Voter storage sender = voters[msg.sender];
        require(! sender.voted, "You already voted.");

        // 如果 to 也给別人了的话，遍历到链条的最后
        while (voters[to].delegate != address(0)) {
            to = voters[to].delegate;
            require(to != msg.sender, "Found loop in delegation.");
        }

        sender.voted = true;
        sender.delegate = to;
        Voter storage delegate_ = voters[to];
        if (delegate_.voted) {
            proposals[delegate_.vote].voteCount += sender.weight;
        } else {
            delegate_.weight += sender.weight;
        }
    }

    function vote(uint proposal) external {
        Voter storage sender = voters[msg.sender];

        require(sender.weight != 0, "Has no right to vote");
        require(!sender.voted, "Already voted.");

        sender.voted = true;
        sender.vote = proposal;

        proposals[proposal].voteCount += sender.weight;
    }

    function winningProposal() public view returns (uint winningProposal_) {
        uint winningVoteCount = 0;
        for (uint p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    function winnerName() external view returns (bytes32 winnerName_) {
        winnerName_ = proposals[winningProposal()].name;
    }
}
