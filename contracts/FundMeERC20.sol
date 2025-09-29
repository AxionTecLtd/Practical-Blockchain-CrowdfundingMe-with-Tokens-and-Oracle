// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 区块链众筹通证和预言机的场景项目实战 Practical Blockchain CrowdfundingMe with Tokens and Oracle
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { FundMe} from './FundMe.sol';


contract FundMeERC20 is ERC20,ERC20Burnable, Ownable {
// ================ variations =====================
// FundMe
// 1.让FundMe的参与者，基于 mapping 来领取相应数量的通证
//2.让FundMe的参与者，transfer 通证
//3.在使用完成以后，需要burn 通证

// 声明合约变量
FundMe fundme ;

 //  ================ constuctor =======================
 constructor( uint256 initialSupply,address fundmeAddr )
        ERC20("FundToken", "FTK") 
        Ownable(msg.sender){ 
        fundme = FundMe(fundmeAddr) ; // 通过合约名（合约地址）方式初始化 

}

// 1.让FundMe的参与者，基于 mapping 来领取相应数量的通证
 function mint(address to, uint256 amountToMint) public  {
    // 调用此方法的人必须为FundMe合约中记录的人，并且余额充足，并且在合约所有者提款标记为true之后
    // C:时间窗口检查-在合约所有者提款标记为true之后
    require(fundme.isGettedFundSucsessed() == true ,'The fundeme has not completed yet.');
    // C:铸币数量检查
    require(fundme.FundersToAmount(msg.sender) >= amountToMint,'insufficient balance') ;
    // E：更新原合约的调用者余额
    // 注意：fundme只是本合约的变量，不方便对外部合约增加新的函数
    // 方案：可以在被调用的合约中，通过被调用的合约中管理员权限设置本合约地址 -> 并新增一个只有本合约地址才能操作的更新函数.然后执行更新
    //这里是 FundMeERC20 合约调用FundMe合约内的函数。所以这里的msg.sender表示交易发起者的合约地址（FROM）——FundMeERC20的合约地址
    fundme.updateFundersToAmount(msg.sender,fundme.FundersToAmount(msg.sender)-amountToMint);
    // I:铸造 amountToMint 数量的通证
      _mint(to,amountToMint);
      
    }
        
//2.让FundMe的参与者，transfer 通证
// 这里ERC20已经有了 transfer 函数，不用再重复写

// gas优化 函数可见性
//3.在使用/兑换claim某种权益假设通证数量-兑换数量-销毁数量为1:1:1）完成以后，需要burn 通证
function claim(uint256 amountToClaimAndBurn) public {
    // C:时间窗口检查-在合约所有者提款标记为true之后
    require(fundme.isGettedFundSucsessed() == true ,'The fundeme has not completed yet.');

    // C:检查交易发起者的余额,要求大于claim的数量
    require(balanceOf(msg.sender) >=amountToClaimAndBurn,'insufficient balance');
    // claim content  function claimToDo()
    // burn
    _burn(msg.sender,amountToClaimAndBurn);


}



}