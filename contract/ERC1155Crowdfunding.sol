// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/AccessControl.sol";
import "@openzeppelin/contracts@4.7.3/security/Pausable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.4.1/security/ReentrancyGuard.sol";

/// @custom:security-contact info@bitsdapps.tech
contract ProjectCrowdfunding is ReentrancyGuard, ERC1155,ERC1155Holder, AccessControl, Pausable, ERC1155Burnable, ERC1155Supply {
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    mapping (uint=>uint) public projectPrice;
    mapping (uint => mapping(address => uint256)) public projectOwnerShares;
    mapping (uint => uint) public projectSales;
    mapping (uint => uint) public projectProfit;
    mapping (address => bool) public addressProjectHolder;
    mapping (uint =>address[]) public projectHolders;
    mapping (uint =>uint) public projectHoldersCount;

    constructor(string memory tokenURI) ERC1155(tokenURI) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mintSell(uint256 id, uint256 amount, bytes memory data, uint256 price)
        public
        onlyRole(MINTER_ROLE)
    {
        _mint(address(this), id, amount, data);
        projectPrice[id]=price;
    }
    function buyProject(uint256 id) public payable nonReentrant(){
        require(msg.value>=projectPrice[id], "not enough for single token");
        if(msg.value>projectPrice[id]){
            _safeTransferFrom(address(this),_msgSender(),id,msg.value/projectPrice[id],'0x0');
            projectOwnerShares[id][_msgSender()]+=msg.value/projectPrice[id];
        }
        else {
            _safeTransferFrom(address(this),_msgSender(),id,1,'0x0');
            projectOwnerShares[id][_msgSender()]+=1;
        }
    }
    function adminTransfer(uint256 id, uint256 amount, address buyer) public onlyRole(DEFAULT_ADMIN_ROLE){
        _safeTransferFrom(address(this),buyer,id,amount,'0x0');
        projectOwnerShares[id][_msgSender()]+=amount;
    }
    function projectSalesWithdraw(uint256 id) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(projectSales[id]>0,"no sales to withdraw");
        payable(_msgSender()).transfer(projectSales[id]);
    }
    function projectProfitDeposit(uint256 id) public payable {
        projectProfit[id]+=msg.value;
    }
    function projectProfitDistribution(uint256 id) public {
     //   for(uint256 i=0;i<=projectHoldersCount[id];i++){
     //       projectHolders[i].transfer(projectProfit*totalSupply(id)/projectOwnerShares[id][address])
     //   }
    }


    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl, ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}
