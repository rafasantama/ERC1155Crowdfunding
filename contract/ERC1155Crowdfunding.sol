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


//Set TimeLock (F)
//Start - End Porjects
//KYC LIST
// EVENTS OF PROJECTS
// AUTOMATIC ID (ADDRESS, FUNCTIONS)
// CheckID EXIST

// DONT OVERRIDE PROJECT

// URI FOR PROJECTS

// Distribucion Justa



/// @custom:security-contact info@bitsdapps.tech
    contract ProjectCrowdfunding is 
    ReentrancyGuard,
    ERC1155,
    ERC1155Holder,
    AccessControl,
    Pausable,
    ERC1155Burnable,
    ERC1155Supply
    
    {
    
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant PROJECTS_ROLE = keccak256("PROJECTS_ROLE");

     struct Project {
        uint256 projectPrice;
        uint256 projectSales;
        address payable[] projectHolders;
        uint256 projectProfit;
        uint256 projectTotalSupply;
        mapping (address => uint256) projectOwnerShares; //mapping (uint256 => address) projectOwnerShares;
        mapping (address => bool) addressProjectHolder;
        mapping (address => uint256) profitGainsByOwner; 
        mapping (address => uint256) profitClaimedByOwner; 
        string projectURI;
    }
        mapping (uint256 => Project) projectStructs;
        mapping (uint256 => string) projectURI;
        Project[] public projectsData;
        uint256 public totalProjects;

        constructor() ERC1155("tokenURI/") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(PROJECTS_ROLE, msg.sender);
    }

    function setURI(string memory _project_URI, uint256 _id) public onlyRole(URI_SETTER_ROLE) {
        projectStructs[_id].projectURI = _project_URI;
    }
    function uri(uint256 _id) public view virtual override returns(string memory) {
        return (projectStructs[_id].projectURI);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }


        //Overrading mintSell
        //********NOTA: implementar mecanismo para cancelar proyectos con errores
        function NewProject(uint256 amount,
        uint256 price, string memory project_URI) public
        onlyRole(PROJECTS_ROLE)
        {
        totalProjects++;
        _mint(address(this), totalProjects, amount,"");
        projectStructs[totalProjects].projectPrice = price;
        projectStructs[totalProjects].projectTotalSupply = amount;
        projectStructs[totalProjects].projectURI = project_URI;
        }

        function getTotalProjectById(uint256 _id) public view
        returns(
        uint256,
        uint256,
        address payable[] memory,
        uint256,
        uint256
        ){
            return(
            projectStructs[_id].projectPrice,
            projectStructs[_id].projectSales,
            projectStructs[_id].projectHolders,
            projectStructs[_id].projectProfit,
            projectStructs[_id].projectTotalSupply
            );
        }
        

        function buyProject2
        (uint256 _id)
        public
        payable
        nonReentrant()
        {
        uint256 priceOfProject = getPriceOfProject(_id);
        require(msg.value>=priceOfProject,"not enough for single token");

            projectStructs[_id].projectOwnerShares[_msgSender()] += msg.value/priceOfProject;
            projectStructs[_id].projectSales += msg.value;
            projectStructs[_id].projectHolders.push(payable(_msgSender()));
            _safeTransferFrom(address(this),_msgSender(),_id,msg.value/priceOfProject,'0x0');
        }


        function adminTransfer
        (uint256 _id,
        uint256 amount,
        address buyer
        ) public
        nonReentrant()
        onlyRole(DEFAULT_ADMIN_ROLE)
        {
            _safeTransferFrom(address(this),buyer,_id,amount,'0x0');
            projectStructs[_id].projectOwnerShares[_msgSender()] =amount;
            //projectOwnerShares[id][_msgSender()]+=amount;
        }


        function getSalesOfProject(uint256 _id)
        internal
        view
        returns(uint256)
        {
            return projectStructs[_id].projectSales;
        }

        function projectSalesWithdraw(uint256 _id) 
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant()
        {
           uint256 salesOfProject = getSalesOfProject(_id);
           require(salesOfProject>0,"no sales to withdraw");
           payable(_msgSender()).transfer(salesOfProject);
        }

        function projectProfitDeposit(uint256 _id)
        public
        payable {
            uint256 deposit = msg.value;
            for (uint i=0;i<=projectStructs[_id].projectHolders.length;i++){
                uint256 ownerPercentage = 100*projectStructs[_id].projectOwnerShares[projectStructs[_id].projectHolders[i]]/projectStructs[_id].projectTotalSupply;
                projectStructs[_id].profitGainsByOwner[projectStructs[_id].projectHolders[i]] += deposit*ownerPercentage;
                //payable(projectStructs[_id].projectHolders[i]).transfer(deposit*ownerPercentage);
            }
            //getProjectGainsOfHolder()
            // projectStructs[_id].projectProfit = deposit;
            //projectStructs[_id].profitGainsByOwner[msg.sender] += 
        }


        function projectProfitDistributionByOwnerCall
        (uint256 _id)
        public
        {
            bool getProof = getProofOfHold(_id);
            require(getProof,"You are not holder project");
            uint256 profitByCaller = getProjectOwnerSharesByOwnerCall(_id);
            payable(msg.sender).transfer(getProjectProfitById(_id)*totalSupply(_id)/profitByCaller);
        }

//----------------------------------------- STRUCT INTERACTION --------------------------------------------------------------



        function getGainsOfHolder(address, uint256) internal {



        }

        function getPriceOfProject(uint256 _id)
        internal
        view
        returns(uint256) {
        return projectStructs[_id].projectPrice;
        }




        function getProofOfHold(uint256 _id)
        internal
        view
        returns(bool)
        {
        return projectStructs[_id].addressProjectHolder[_msgSender()];
        }

        function getHoldersById(uint256 _id)
        internal
        view
        returns(address payable[] memory)
        {
            return projectStructs[_id].projectHolders;
        }

        function getProjectProfitById(uint256 _id)
        internal
        view
        returns(uint256)
        {
        return projectStructs[_id].projectProfit;
        }

        function getProjectOwnerSharesByOwnerCall(uint256 _id)
        internal
        view
        returns(uint256)
        {
            return projectStructs[_id].projectOwnerShares[_msgSender()];
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
    