const hre = require("hardhat");

async function main() {
    try {
        // 계정 가져오기
        const [owner, manager, investor1, investor2] = await ethers.getSigners();
        console.log("테스트 실행 계정:", owner.address);

        // 1. 컨트랙트 배포
        console.log("\n1. BCMDSTO 컨트랙트 배포 중...");
        const BCMDSTO = await ethers.getContractFactory("BCMDSTO");
        const token = await BCMDSTO.deploy(
            "BCMD Security Token",           // name
            "BCMD",                          // symbol
            100, // totalSupply
            10 // maxInvestment
        );
        await token.waitForDeployment();
        console.log("컨트랙트 주소:", token.address);

        // 2. 기본 정보 확인
        console.log("\n2. 토큰 정보 확인");
        const name = await token.name();
        const symbol = await token.symbol();
        const totalSupply = await token.totalSupply();
        console.log("토큰 이름:", name);
        console.log("토큰 심볼:", symbol);
        console.log("총 발행량:", totalSupply);

        // 3. Compliance Manager 설정
        console.log("\n3. Compliance Manager 설정");
        await token.setComplianceManager(manager.address);
        console.log("새로운 Compliance Manager:", manager.address);

        // 4. 투자자 화이트리스트 등록 및 KYC 승인
        console.log("\n4. 투자자 등록 프로세스");
        await token.connect(manager).addToWhitelist(investor1.address, true);
        await token.connect(manager).approveKYC(investor1.address, "KYC_HASHED_DATA");
        console.log("Investor1 화이트리스트 등록 완료");
        
        // 5. 전문 투자자 등록
        await token.connect(manager).approveExpert(investor1.address, true);
        console.log("Investor1 전문투자자 등록 완료");

        // 6. 토큰 전송 테스트
        console.log("\n5. 토큰 전송 테스트");
        const transferAmount = 3;
        await token.transfer(investor1.address, transferAmount);
        const investor1Balance = await token.balanceOf(investor1.address);
        console.log("Investor1 잔액:", investor1Balance);

        // 7. 월별 수익 기록 테스트
        console.log("\n6. 월별 수익 기록");
        await token.connect(manager).recordMonthlyRevenue(
            2024,
            3,
            1000,
            "2024년 3월 수익"
        );
        const revenue = await token.getMonthlyRevenue(2024, 3);
        console.log("2024년 3월 수익:", revenue.revenue);

        // 8. 투표 생성 및 참여 테스트
        console.log("\n7. 투표 프로세스 테스트");
        const votingPeriod = 7 * 24 * 60 * 60; // 7일
        await token.connect(manager).createProposal("신규 사업 투자 결정", votingPeriod);
        console.log("투표 생성 완료");

        await token.connect(investor1).vote(0, true);
        console.log("Investor1 투표 완료");

        const voteResults = await token.getVoteResults(0);
        console.log("투표 현황:");
        console.log("- 찬성:", voteResults.forVotes);
        console.log("- 반대:", voteResults.againstVotes);
        console.log("- 상태:", voteResults.status);

    } catch (error) {
        console.error("\n에러 발생:", error);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });