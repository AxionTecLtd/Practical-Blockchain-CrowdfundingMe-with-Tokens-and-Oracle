// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 区块链众筹通证和预言机的场景项目实战 Practical Blockchain CrowdfundingMe with Tokens and Oracle
// 引入 合约
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
// 众筹场场景：众筹——达到目标——生产——通证
//1.创建一个收款函数
//2，记录投资人并且查看
// 2.2 设置最小投资金额并检查
// 2.1 pro 为了贴近用户使用习惯（如ETH对USD）价格，需要通过预言机喂价服务，引入外部资产价格数据，转换为外部货币对。
// 数据馈送。经常用于 DeFi、体育、天气等的去中心化和高质量数据。act in real-time on data such as prices of assets. This is especially true in DeFi.
//3.在锁定期内，达到目标值，生产商可以提款
//4，在锁定期内，没有达到目标值，投资人在锁定期以后退款
// 边开发边运行，方便测试，别写完了到处排查问题又浪费时间和重写
// 自定义对象（类型）大驼峰，自定义方法函数小驼峰，内置一切小驼峰
// 变量编写业务函数边补充

contract FundMe {

// =============== variatons defination ===============
// who 、when、mapping_record_dict 、how much/many 、status/flag 标记 几类变量
// === 引入部分 =====
// 声明合约对象类型dataFeed，一个合约也可以作为一种数据类型class，也具有方法
AggregatorV3Interface internal dataFeed;
// 合约归属人 ( who )
address public owner ;
//2，记录投资人并且查看  ( mapping_record_dict: key = who , value = balance)
// mppping(key => value)键值对。
mapping (address =>uint256) public FundersToAmount; // 投资人地址金额映射表
// 最低100 u  ( how much )
uint256 constant public MINIMUM_USD = 3;  // USD
uint256  constant TARGET_AMOUNT_ETH = 1*10**18; // 1eth = 10**18wei
// 时间窗口 锁定期内 ( when )
uint256 internal deployTimestamp ;
uint256 internal lockDurationTime ;
// 标记 ( status/flag )
bool public isGettedFundSucsessed = false; // 标记投资人是否已经提款，方便知晓最终状态
// 外部合约地址 用于外部合约地址调用本合约特定函数。更改投资人的账户余额，匹配通证数量,安全性有待考量
address public erc20Address  ;

// ============= 初始化 ==================
// 部署时候初始化设定,后期当常量使用
 /**
     * Network: Sepolia
     * Aggregator: ETH / USD 
     * Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
     */
constructor(){
    deployTimestamp = block.timestamp; // 部署时候的矿工打包,表示问世以来累计的时间戳秒数，后一个区块严格大于前一个区块
    lockDurationTime = 60 ; // second 秒
    owner =msg.sender;
    dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
}


// =========== events ===================
// 返回提示和前端使用

// =========== 装饰器 ===================
// when 时间锁 装饰器 
// 在合约锁定期内
modifier  windowOn(){
    // 生成时间+锁定时间>=新交易区块时间
    require(deployTimestamp+lockDurationTime>=block.timestamp,'Window has closed.');
    _; //继续执行下面逻辑 next()
}
// 不在合约锁定期内
modifier  windowClosed(){
    // 生成时间+锁定时间<新交易区块时间 (严格小于）
    require(deployTimestamp+lockDurationTime<block.timestamp,'Window has not closed yet.');
    _; //继续执行下面逻辑 next()
}

// Permissions 权限类 修饰器 
modifier onlyOwner(){
   require(msg.sender == owner,'Only owner can call this function.');
   _;
}


// ========== 合约核心业务逻辑 ================

// 管理员权限,通过设置传入erc20合约地址_erc20Address，来更新全局变量 erc20Address
// 注意：此函数只有管理员权限才能设置
function setErc20Address(address _erc20Address) public onlyOwner{
    erc20Address = _erc20Address;
}

// 通过传入FundersToAmount余额表中的funder地址,设置FundersToAmount中key对应的value,来更新funder的余额。
// 注意check：此函数只有前文通过管理员权限设置的 erc20Address 合约地址,才能发起交易，调用此函数
function updateFundersToAmount(address funder,uint256 updateToAmount) public {
    require(msg.sender==erc20Address,'Only erc20Address can call this function.'); // C
    FundersToAmount[funder] = updateToAmount;  // E 为了标准性，直接设置结果值

}


// 1.创建一个收款函数
// payable 关键字 表示点击调用这个函数，可以接收转账，接收人为该合约的部署者
 function fundme() external payable {
    require(convertEthToUsd(msg.value) >= MINIMUM_USD,"send more ETH");
    // msg.sender 为在一笔交易中，的发送这笔交易的人
    // msg.value 为在这笔交易中，发送的token数量
    FundersToAmount[msg.sender]=msg.value;  // 更新金额记录表，记录投资人发送的金额，FundersToAmount[key]方式，赋值给value

 }
 
//3.在锁定期内，达到目标值，生产商本人可以提款,透明性公开可见
// 转账操作 CEI模式 
function getFund() windowClosed onlyOwner public {
    // C:windowClosed 、onlyOwner
    // C:已经达到目标值
    require(address(this).balance >= TARGET_AMOUNT_ETH,'Not reached the goal amount');
    // E:执行更新提款标记
    isGettedFundSucsessed = true; 
    // I:转账给所有者 addr.call{value:value}('')
    (bool success,) = payable (msg.sender).call{value:address(this).balance}('');
    require(success==true,'Transfer is failed.');
}

//4，在锁定期内，没有达到目标值，金额足够，投资人在锁定期以后退款 （检查条件先后顺序得当可以省gas)
function withDrawFund(uint256 getAmount) windowOn public{
    // C:没有达到目标值
    require(address(this).balance < TARGET_AMOUNT_ETH,'Has reached the goal amount');
    // C:金额足够 windowOn 
    require(FundersToAmount[msg.sender]>=getAmount,'Insufficient balance');
    // E:执行更新余额
    FundersToAmount[msg.sender] -= getAmount;
    // I:转账给调用者
    (bool success,) = payable (msg.sender).call{value:FundersToAmount[msg.sender]}('');
    require(success==true,'Transfer is failed.');
}





// ========== helper tools ================
// ETH -> USD 转换函数
   function convertEthToUsd(uint256 ethAmount) internal view returns (uint256) {
       uint256 ethPrice = uint256(getChainlinkDataFeedLatestAnswer()); 
       // ethPrice 单位：USD * 1e8
       // ethAmount 单位：wei (1e18 wei = 1 ETH)
       uint256 usdAmount = (ethAmount * ethPrice) / (1e18 * 1e8);
       return usdAmount;
   }


// 引入预言机喂价服务函数
    /**
    * Returns the latest answer.单位：USD * 1e8
    */
   function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundId */,
            int256 answer,
            /*uint256 startedAt*/,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }


// 告诉用户要满足最低 USD 投资额，需要多少 ETH
    function getMinimumEth() public view returns (uint256) {
        uint256 ethPrice = uint256(getChainlinkDataFeedLatestAnswer()); 
        // ethPrice 单位：USD * 1e8
        uint256 ethNeeded = (MINIMUM_USD * 1e18 * 1e8) / ethPrice;
        return ethNeeded; // 单位：wei
    }




}

