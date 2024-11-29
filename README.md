# 2024bcmd-sto
2024년 블록체인 밋업데이 토큰증권 제도화와 스마트컨트랙트 강의자료입니다.

## 프로젝트
- sample: 간결한 토큰증권 컨트랙트
- UniversalToken-master: ERC-1400 컨트랙트





### hardhat 사용방법
1. hardhat 프로젝트 설정<br/>
npm init -y <br/>
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox<br/>
npx hardhat init<br/>

2. 로컬네트워크 시작<br/>
npx hardhat node<br/>

3. 로컬네트워크 테스트<br/>
npx hardhat run scripts/test-bcmd-sto.js --network localhost<br/>


기타<br/>

- 초기화<br/>
npx hardhat clean<br/>