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
        bool projectActive;
        bool crowfundingPhase;
        string projectURI;
    }
        mapping (uint256 => Project) projectStructs;
        //mapping (uint256 => string) projectURI;
        uint256 public totalProjects;

        //EVENTOS PARA CADA FUNCIÓN
        event NewProjectCreated();
        event ProjectCanceleted();
        event PhaseCrowEnd();

        modifier emergency(uint256 _id){
            require(projectStructs[_id].projectActive, "Project is not activated");
            _;
        }

        // KYC LIMIT 1000$
        // CELO USD
        // ETH CONSULTAR PRECIO DEX
        // PAGOS Y RETIROS EN CELO USD
        // TRABAJANDO EN ELLO...


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
        _mint(address(this), totalProjects, amount,"");
        projectStructs[totalProjects].projectPrice = price;
        projectStructs[totalProjects].projectTotalSupply = amount;
        projectStructs[totalProjects].projectURI = project_URI;
        projectStructs[totalProjects].projectActive = true;
        projectStructs[totalProjects].crowfundingPhase = false;
        totalProjects++;
        }

        function cancelProjectEmergency
        (uint256 _id, bool _cancel)
        public 
        onlyRole(PROJECTS_ROLE)
        {
                projectStructs[_id].projectActive = _cancel;
        }

        function startAndEndCrowfundingProject(uint256 _id, bool x) public {
            projectStructs[_id].crowfundingPhase = x;
        }

// ------------------------------- GET INFO PROJECT --------------------------------------
        function getTotalProjectById(uint256 _id) public view 
        returns(
        uint256,
        uint256,
        address payable[] memory,
        uint256,
        uint256,
        bool,
        string memory
        ){
            return(
            projectStructs[_id].projectPrice,
            projectStructs[_id].projectSales,
            projectStructs[_id].projectHolders,
            projectStructs[_id].projectProfit,
            projectStructs[_id].projectTotalSupply,
            projectStructs[_id].projectActive,
            projectStructs[_id].projectURI
            );
        }

        function getPhaseOfProject(uint256 _id) public view returns(bool)
    {
        return projectStructs[_id].crowfundingPhase;
    }

// ------------------------------- PROJECT BUY --------------------------------------

        // BUG EL CONTRATO SE QUEDA CON 0.5 TOKEN
        // AMOUNT CON DECIMALES 18
        // PRICE CON DECIMALES 18
        // STRUCT SHARES CON DECIMALES PARA CONTABILIZAR LOS RETIROS O PROFIT. PERO EL ERC1155 SIN 18 DECIMALES?
        // TRABAJANDO EN ELLO...
        function buyProject2
        (uint256 _id)
        public
        payable
        nonReentrant()
        emergency(_id)
        {
        require(projectStructs[_id].crowfundingPhase,"Project is not Started yet");
        require(msg.value>=projectStructs[_id].projectPrice,"not enough for single token");
            //msg.value/PriceOfProject
            //projectStructs[_id].projectOwnerShares[_msgSender()] += msg.value/priceOfProject;
            projectStructs[_id].projectOwnerShares[_msgSender()] += msg.value * 10**18/projectStructs[_id].projectPrice;
            projectStructs[_id].projectSales += msg.value;
            projectStructs[_id].projectHolders.push(payable(_msgSender()));
            projectStructs[_id].addressProjectHolder[_msgSender()] = true;
            _safeTransferFrom(address(this),_msgSender(),_id,msg.value * 10**18/projectStructs[_id].projectPrice,'0x0');
        }


// ------------------------------- PROJECT WITHDRAW --------------------------------------

        function projectSalesWithdraw(uint256 _id) 
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant()
        {
           uint256 salesOfProject = projectStructs[_id].projectSales;
           require(salesOfProject>0,"no sales to withdraw");
           payable(_msgSender()).transfer(salesOfProject);
        }

// ------------------------------- PROJECT PROFIT --------------------------------------


        function projectProfitDeposit(uint256 _id)
        public
        payable 
        nonReentrant()
        emergency(_id)
        onlyRole(PROJECTS_ROLE){
            uint256 length = projectStructs[_id].projectHolders.length;
            for (uint i=0;i<length;i++){
                address payable addr = projectStructs[_id].projectHolders[i];
                uint256 ownerPercentage = msg.value*projectStructs[_id].projectOwnerShares[addr]/projectStructs[_id].projectTotalSupply;
                projectStructs[_id].profitGainsByOwner[addr] += ownerPercentage;
        }
        }


        function projectProfitDistributionByOwnerCall
        (uint256 _id)
        public
        {
            require(projectStructs[_id].addressProjectHolder[msg.sender],"You are not holder project");
            uint256 profitByCaller = projectStructs[_id].profitGainsByOwner[msg.sender];
            payable(msg.sender).transfer(profitByCaller);
            projectStructs[_id].profitGainsByOwner[msg.sender] -= profitByCaller;
            projectStructs[_id].profitClaimedByOwner[msg.sender] += profitByCaller;
        }

     function projectProfitDepositDistribution(uint256 _id)
        public
        payable
        nonReentrant()
        emergency(_id)
        onlyRole(PROJECTS_ROLE){
            uint256 length = projectStructs[_id].projectHolders.length;
            for (uint i=0;i<length;i++){
                address payable addr = projectStructs[_id].projectHolders[i];
                uint256 ownerPercentage = msg.value*projectStructs[_id].projectOwnerShares[addr]/projectStructs[_id].projectTotalSupply;
                projectStructs[_id].profitGainsByOwner[addr] += ownerPercentage;
                payable(addr).transfer(projectStructs[_id].profitGainsByOwner[addr]);
                projectStructs[_id].profitGainsByOwner[addr] -= ownerPercentage;
                projectStructs[_id].profitClaimedByOwner[addr] += ownerPercentage;
        }
        }

        //PAYS OFF-CHAIN
        // PAGOS OFF CHAIN, FIAT

        /*function adminTransfer
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
        }*/

//----------------------------------------- STRUCT INTERACTION --------------------------------------------------------------

        function getProofOfHold(uint256 _id)
        internal
        view
        returns(bool)
        {
        return projectStructs[_id].addressProjectHolder[_msgSender()];
        }

//-------------------------------------------------------------------------------------------------------------------------

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
    