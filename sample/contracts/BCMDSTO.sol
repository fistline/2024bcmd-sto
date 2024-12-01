// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

/***
[기본기능]
- 발행하기
- 전달하기
- 소각하기

[기초자산]
- 발행량
- 기초자산의 현재가치를 실시간 반영(월별)

[내부통제]
- 내부고객대상
- KYC를 진행
- 전문투자자와 일반투자자 구분

[청약및배정]
- 투자자별  최대량 제한

[투자자권리]
- 투자자총회를 구현
 */

pragma solidity ^0.8.0;

contract BCMDSTO {
    string public name;
    string public symbol;
    uint256 public totalSupply;
    uint256 public maxInvestment;
    
    address public owner;
    address public complianceManager;
    
    // 월별 수익 구조체
    struct MonthlyRevenue {
        uint256 revenue;      // 수익
        uint256 timestamp;    // 기록 시간
        string note;          // 비고
    }
    // 투표 구조체
    struct Proposal {
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    // 투표 저장소
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    // 연도별, 월별 수익 기록
    mapping(uint256 => mapping(uint256 => MonthlyRevenue)) public monthlyRevenues; // year => month => revenue

    //고객별 증권수량DB 
    mapping(address => uint256) public balanceOf;
    //등록고객 여부 DB
    mapping(address => bool) public whitelist;
    //고객확인여부 DB
    mapping(address => bool) public kycApproved;
    //투자자정보
    mapping(address => Investor) public investors;
    
    uint256 public currentInvestorCount;
    bool public transfersFrozen;
    
    struct Investor {
        bool exists;
        bool expert;
        uint256 investedAmount;
        uint256 timestamp;
        string kycHash;
    }
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event WhitelistChanged(address indexed investor, bool _allow);
    event KYCApproved(address indexed investor);
    event ExpertApproved(address indexed investor);
    event TransfersFrozen(bool status);
    event ComplianceManagerChanged(address indexed newManager);
    event ProposalCreated(uint256 indexed proposalId, string description, uint256 startTime, uint256 endTime);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);
    event TokensBurned(address indexed burner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyComplianceManager() {
        require(msg.sender == complianceManager, "Only compliance manager can call this function");
        _;
    }
    
    modifier whenNotFrozen() {
        require(!transfersFrozen, "Transfers are currently frozen");
        _;
    }
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _maxInvestment
    ) {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        maxInvestment = _maxInvestment;
        owner = msg.sender;
        complianceManager = msg.sender;
        balanceOf[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }
    
    // 화이트리스트 관리
    function addToWhitelist(address _investor, bool _allow) public onlyComplianceManager {
        require(!whitelist[_investor], "Investor already whitelisted");
        whitelist[_investor] = _allow;
        emit WhitelistChanged(_investor, _allow);
    }
    
    // KYC 등록
    function approveKYC(address _investor, string memory _kycHash) public onlyComplianceManager {
        require(whitelist[_investor], "Investor not whitelisted");
        kycApproved[_investor] = true;
        
        if (!investors[_investor].exists) {
            currentInvestorCount++;
            investors[_investor].exists = true;
            investors[_investor].timestamp = block.timestamp;
        }
        investors[_investor].kycHash = _kycHash;
        
        emit KYCApproved(_investor);
    }

    // 전문투자자 등록
    function approveExpert(address _investor, bool _allow ) public onlyComplianceManager {
        require(whitelist[_investor], "Investor not whitelisted");
        require(kycApproved[_investor], "Investor not KYC");
        
        investors[_investor].expert = _allow;
        emit ExpertApproved(_investor);
    }
    
    // 관리자 등록
    function setComplianceManager(address _newManager) public onlyOwner {
        require(_newManager != address(0), "Invalid address");
        complianceManager = _newManager;
        emit ComplianceManagerChanged(_newManager);
    }
    
    // 거래제한
    function freezeTransfers(bool _status) public onlyComplianceManager {
        transfersFrozen = _status;
        emit TransfersFrozen(_status);
    }
    
    // 투자 제한 검증 함수
    function validateTransfer(
        address _to,
        uint256 _value
    ) internal view returns (bool) {
        require(whitelist[_to], "Recipient not whitelisted");
        require(kycApproved[_to], "Recipient KYC not approved");
        
        uint256 newAmount = investors[_to].investedAmount + _value;

        // 전문투자자가 아닌경우, 투자한도 적용
        if(investors[_to].expert == false ){
            require(newAmount <= maxInvestment, "Exceeds maximum investment");
        }
        return true;
    }
    
    // ERC20 기본 함수 오버라이드
    function transfer(address _to, uint256 _value) public whenNotFrozen returns (bool) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        require(_to != address(0), "Invalid address");
        require(validateTransfer(_to, _value), "Transfer validation failed");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        investors[_to].investedAmount += _value;
        
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // 소각 기능 (소유자만 호출 가능)
    function burn(uint256 amount) public onlyOwner {
        require(balanceOf[owner] >= amount, "Insufficient balance to burn");
        
        balanceOf[owner] -= amount;
        totalSupply -= amount;

        emit TokensBurned(owner, amount); // 소각 이벤트 발생
    }
    

    // 간단히 보유량만 확인하는 함수
    function getSecurityBalance(address _investor) 
        public 
        view 
        returns (uint256) 
    {
        require(_investor != address(0), "Invalid address");
        return balanceOf[_investor];
    }



 /******************** 기초자산 수익등록 ********************/

    // 월별 수익 기록
    function recordMonthlyRevenue(
        uint256 year,
        uint256 month,
        uint256 revenue,
        string memory note
    ) public onlyComplianceManager {
        require(month >= 1 && month <= 12, "Invalid month");
        require(year >= 2000 && year <= 2100, "Invalid year");
        
        monthlyRevenues[year][month] = MonthlyRevenue({
            revenue: revenue,
            timestamp: block.timestamp,
            note: note
        });
    }
    
    // 특정 월의 수익 조회
    function getMonthlyRevenue(uint256 year, uint256 month) public view returns (
        uint256 revenue,
        uint256 timestamp,
        string memory note
    ) {
        require(month >= 1 && month <= 12, "Invalid month");
        MonthlyRevenue memory rev = monthlyRevenues[year][month];
        return (rev.revenue, rev.timestamp, rev.note);
    }
    
    // 연간 총 수익 조회
    function getYearlyRevenue(uint256 year) public view returns (
        uint256 totalRevenue,
        uint256[] memory monthlyRevs
    ) {
        monthlyRevs = new uint256[](12);
        for(uint256 i = 1; i <= 12; i++) {
            monthlyRevs[i-1] = monthlyRevenues[year][i].revenue;
            totalRevenue += monthlyRevenues[year][i].revenue;
        }
        return (totalRevenue, monthlyRevs);
    }
    
    // 특정 기간의 수익 조회
    function getRevenueForPeriod(
        uint256 startYear,
        uint256 startMonth,
        uint256 endYear,
        uint256 endMonth
    ) public view returns (
        uint256 totalRevenue,
        uint256 monthCount
    ) {
        require(startMonth >= 1 && startMonth <= 12, "Invalid start month");
        require(endMonth >= 1 && endMonth <= 12, "Invalid end month");
        require(startYear <= endYear, "Invalid year range");
        
        for(uint256 year = startYear; year <= endYear; year++) {
            uint256 monthStart = (year == startYear) ? startMonth : 1;
            uint256 monthEnd = (year == endYear) ? endMonth : 12;
            
            for(uint256 month = monthStart; month <= monthEnd; month++) {
                totalRevenue += monthlyRevenues[year][month].revenue;
                monthCount++;
            }
        }
        
        return (totalRevenue, monthCount);
    }
/******************** 투표 ********************/

   /*** 투자자집회 */
    // 찬반 투표 생성하기
    function createProposal(string memory description, uint256 votingPeriod) public onlyComplianceManager returns (uint256) {
        require(votingPeriod > 0, "Voting period must be positive");
        uint256 proposalId = proposalCount++;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + votingPeriod;
        
        emit ProposalCreated(proposalId, description, newProposal.startTime, newProposal.endTime);
        return proposalId;
    }


    //찬반 투표하기
    function vote(uint256 proposalId, bool support) public {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp < proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(balanceOf[msg.sender] > 0, "Must have tokens to vote");

        proposal.hasVoted[msg.sender] = true;
        uint256 votes = balanceOf[msg.sender];

        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        emit Voted(proposalId, msg.sender, support, votes);
    }

    // 투표결과 실행
    function executeProposal(uint256 proposalId) public onlyComplianceManager {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Already executed");
        
        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    // 투표 결과확인
    function getProposal(uint256 proposalId) public view returns (
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed
        );
    }
    // 투표여부확인
    function hasVoted(uint256 proposalId, address voter) public view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    // 투표 진행여부 확인
    function isVotingOpen(uint256 proposalId) public view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return (
            block.timestamp >= proposal.startTime &&
            block.timestamp < proposal.endTime &&
            !proposal.executed
        );
    }

    // 투표 결과 상세 조회
    function getVoteResults(uint256 proposalId) public view returns (
        string memory description,    // 제안 설명
        uint256 forVotes,            // 찬성 투표 수
        uint256 againstVotes,        // 반대 투표 수
        uint256 totalVotes,          // 총 투표 수
        bool isEnded,                // 투표 종료 여부
        bool isExecuted,             // 실행 여부
        string memory status         // 현재 상태
    ) {
        Proposal storage proposal = proposals[proposalId];
        totalVotes = proposal.forVotes + proposal.againstVotes;
        isEnded = block.timestamp >= proposal.endTime;
        
        // 상태 결정
        string memory currentStatus;
        if (!isEnded) {
            currentStatus = "Voting in progress";
        } else if (proposal.executed) {
            currentStatus = "Executed";
        } else if (proposal.forVotes > proposal.againstVotes) {
            currentStatus = "Passed";
        } else {
            currentStatus = "Rejected";
        }

        return (
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            totalVotes,
            isEnded,
            proposal.executed,
            currentStatus
        );
    }
    
    // 투표 참여율 확인
    function getVoteParticipation(uint256 proposalId) public view returns (
        uint256 participationRate,   // 참여율
        uint256 voterCount           // 총 투표자 수
    ) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        
        // 참여율 계산
        if (totalSupply > 0) {
            participationRate = totalVotes / totalSupply;
        }
        
        return (participationRate, totalVotes);
    }

}