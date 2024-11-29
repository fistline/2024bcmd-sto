const hre = require("hardhat");

async function main() {
  // 배포 계정 가져오기
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // 배포 계정의 잔액 표시
//   const balance = await deployer.balanceOf();
//   console.log("Account balance:", ethers.utils.formatEther(balance));

  // 컨트랙트 배포

// string memory _name,
// string memory _symbol,
// uint256 _totalSupply,
// uint256 _maxInvestment
  const Token = await ethers.getContractFactory("BCMDSTO");
  const token = await Token.deploy("BCMDSTO", "BCM", 60, 10);
  await token.waitForDeployment();

  console.log("Token deployed to:", token.address);

  // 배포된 토큰의 정보 출력
  const name = await token.name();
  const symbol = await token.symbol();
  const totalSupply = await token.totalSupply();
  
  console.log("Token Name:", name);
  console.log("Token Symbol:", symbol);
  console.log("Total Supply:", totalSupply);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });