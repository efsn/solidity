// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

/// @title 委托投票
contract Ballot {

    // 这里声明了一个新的复合类型用于稍后的变量
    // 它用来标识一个选民
    struct Voter {
        uint weight; // 计票权重
        bool voted; // 是否投票
        address delegate; // 被委托人
        uint vote; // 投票提案的索引
    }

    // 提案类型
    struct Proposal {
        bytes32 name;
        uint voteCount; // 得票数
    }

    address public chairPerson;

    // 这声明了一个状态变量，为每个可能的地址存储一个Voter
    mapping(address => Voter) public voters;

    Proposal[] public proposals;

    // 为proposal names中的 每个提案，创建一个新的投票表决
    constructor(bytes32[] memory proposalNames) {
        chairPerson = msg.sender;
        voters[chairPerson].weight = 1;

        // 对于提供的每个提案名称
        // 创建一个新的proposal对象并把它添加到数组的末尾
        for (uint i = 0; i < proposalNames.length; i++) {
            proposals.push(Proposal({name : proposalNames[i], voteCount : 0}));
        }
    }

    // 授权voter对这个proposal进行投票
    // 只有chairPerson可以invoke该function
    function giveRight2Vote(address voter) public {
        /*
        若require的第一个参数计算结果为false，则终止执行，撤销所有对状态和以太币余额的改动
        在旧版的EVM中这曾经会消耗所有gas，但现在不会了
        使用require来检查函数是否被正确地调用
        */
        require(msg.sender == chairPerson, "only chair person can give right to vote");
        require(!voters[voter].voted, "the voter already voted");
        require(voters[voter].weight == 0);
        voters[voter].weight = 1;
    }

    function delegate(address to) public {
        // 传引用
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "you already voted");
        require(to != msg.sender, "self delegate is disabled");

        /*
        委托是可以传递的，只要被委托者to也设置了委托
        一般这种循环委托是危险的，如果传递的链条太长，可能需消耗gas要多余区块中剩余的
        大于区块设置的gasLimit
        这种情况下，委托不会执行
        而在另一些情况下，如果形成闭环，则会让合约完全卡住
        */
        while (voters[to].delegate != address[0]) {
            to = voters[to].delegate;
            require(to != msg.sender, "found loop in delegation");
        }

        // sender是一个引用，相当于voter[msg.sender].voted进行修改
        sender.voted = true;
        sender.delegate = to;
        Voter storage delegate_ = voters[to];
        if (delegate_.voted) {
            // 若被委托者已经投过票了，直接增加得票数
            proposals[delegate_.vote].voteCount += sender.weight;
        } else {
            // 若被委托者还没有投票，增加委托者的全权重
            delegate_.weight += sender.weight;
        }
    }

    // 把你的票（包括委托）
    // 投给提案 proposals[proposal].name
    function vote(uint proposal) public {
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "already voted");
        sender.voted = true;
        sender.vote = proposal;

        // 如果proposal超过了数组的范围，则会自动抛出异常，并恢复所有的改动
        proposals[proposal].voteCount += sender.weight;
    }

    function winProposal() public view returns (uint winProposal_) {
        uint winVoteCount = 0;
        for (uint p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winVoteCount) {
                winVoteCount = proposals[p].voteCount;
                winProposal_ = p;
            }
        }
    }

    // 调用winProposal()以获取提案数组中获胜者的索引，并以此返回获胜者的名称
    function winnerName() public view returns (bytes32 winnerName_){
        winnerName_ = proposals[winProposal()].name;
    }

}
