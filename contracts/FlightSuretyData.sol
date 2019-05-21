pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true; 

                                       // Blocks all state changes throughout the contract if false
    mapping(address => uint256) private authorizedCallers;

    struct Airline {
        bool isRegistered;
        uint256 funds;
    }

    mapping(address => Airline) airlines;
    address[] private registeredAirlines;

    // passenger with multiply flights
    struct Passenger {
        bool isInsured;     //is insured multiple?
        bool[] isPaid;
        uint256[] insurance;
        string[] flights;
    }

    mapping(address => Passenger) passengersMapping;

    mapping(string => address[]) flightPassengers;

    // the contract holds balance of insurance
    uint256 private balance = 0 ether;
    // registration fee
    uint256 constant registration = 10 ether;

    // consensus of registered airlines
    address[] public multiCalls = new address[](0);

///////////////// Possibly reuse 
    //Flight mapping Amount
    mapping(string => uint256) private flightInsuranceTotalAmount;

    //Passenger address to insurance payment. Stores Insurance payouts for passengers
    // passenger[i].flight passenger[i].funds
    mapping(address => uint256) private insurancePayment;
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address _airline
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        initialAirline(_airline);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsCallerAuthorized()
    {
        require(authorizedCallers[msg.sender] == 1, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function initialAirline(address _airline) internal requireIsOperational{
        airlines[_airline] = Airline({isRegistered : true, funds : 0});
        registeredAirlines.push(_airline);
    }
    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */   

    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner
                             
    {
        operational = mode;
    } 

    function authorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        authorizedCallers[contractAddress] = 1;
    }

    function deauthorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        delete authorizedCallers[contractAddress];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function isAirline
                            (
                                address _address
                            )
                            external
                            view
                            returns(bool)
    {
        return airlines[_address].isRegistered;
    }
   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            ( 
                                address _address   
                            )
                            external
                            requireIsOperational
    {  
        airlines[_address] = Airline ({
                                        isRegistered: true,
                                        funds: 0

                                    });
        registeredAirlines.push(_address);
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (   
                            address _passenger,
                            uint256 _insurancePrice,
                            string _flight
                            )
                            external
                            payable
                            requireIsOperational
    {
        string[] memory flights = new string[](3);
        bool[] memory paid = new bool[](3);
        uint256[] memory insurance = new uint[](3);
        uint index;

        if(passengersMapping[_passenger].isInsured == true){
            index = getFlightIndex(_passenger, _flight) ;

            require(index == 0, "Passenger has alredy been insured.");

            //otherwise input another insurance
            passengersMapping[_passenger].isPaid.push(false);
            passengersMapping[_passenger].insurance.push(_insurancePrice);
            passengersMapping[_passenger].flights.push(_flight);

        }else {
            paid[0] = false;
            insurance[0] = _insurancePrice;
            flights[0] = _flight;
            passengersMapping[_passenger] = Passenger({isInsured: true, isPaid: paid, insurance: insurance, flights: flights});
        }

        // insurance amount cal
        insurancePayment[_passenger] = _insurancePrice;
        balance = balance.add(_insurancePrice);
        flightPassengers[_flight].push(_passenger);
        flightInsuranceTotalAmount[_flight] = flightInsuranceTotalAmount[_flight].add(_insurancePrice);

    }

    /**
     *  @dev Credits payouts to insurees
    
    function creditInsurees
                                ( 
                                    address _passenger,
                                    uint _credit
                                )
                                internal
    {        
        passengers[_passenger].isPaid = true;
        passengers[_passenger].insurance = passengers[_passenger].insurance.add(_credit);
        passengers[_passenger].isInsured = false;
    }*/
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *  Each insuree receives the equal part of total amount of airline insurance
     *
    */
    function pay
                            (
                                address _account,
                                uint funds
                            )
                            public
                            payable
                            requireIsOperational
    {
        _account.send(funds);
        
    }

    function getInsurancePayment(address _account) external view requireIsOperational returns (uint funds){
        return insurancePayment[_account];
    }


    function setInsurancePayment(address _account) external requireIsOperational{
        insurancePayment[_account] =0;
    }

    function substractBalance(uint funds) external requireIsOperational{
        balance = balance.sub(funds);
    }

    function getInsureOfFlight(string _flight, address _passenger) external view requireIsOperational returns (uint amount){
        uint index = getFlightIndex(_passenger, _flight) - 1;
        if(passengersMapping[_passenger].isPaid[index] == false)
        {
            return passengersMapping[_passenger].insurance[index];
        }
        return 0;
    }

    function setInsureOfFlight(string _flight, address _passenger,uint _amount) external requireIsOperational{
        uint index = getFlightIndex(_passenger, _flight) - 1;
        passengersMapping[_passenger].isPaid[index] = true;
        insurancePayment[_passenger] = insurancePayment[_passenger].add(_amount);
    }

    function getPassengersInsured(string _flight) external view requireIsOperational returns(address[] passengers){
        return flightPassengers[_flight];
    }

    function getNoOfRegisteredAirlines() public view requireIsOperational returns (uint num){
        return registeredAirlines.length;
    }

    function isAirlineRegistered(address _airline) public view requireIsOperational returns (bool success) {
        return airlines[_airline].isRegistered;
    }


    function getMultiCallsLength() public view returns(uint){
        return multiCalls.length;
    }

    function getMultiCallsItem(uint _i) public view returns(address){
        return multiCalls[_i];
    }
    function setMultiCallsItem(address _address) public {
        multiCalls.push(_address);
    }

    function clearMultiCalls() public{
        multiCalls = new address[](0);
    }

    function getRegisteredAirlines() requireIsOperational public view returns(address[]){
        return registeredAirlines;
    }


    function getFlightIndex(address _passenger, string memory _flight) public view returns(uint index)
    {
        string[] memory flights = new string[](5);
        flights = passengersMapping[_passenger].flights;

        for(uint i = 0; i < flights.length; i++){
            if(uint(keccak256(abi.encodePacked(flights[i]))) == uint(keccak256(abi.encodePacked(_flight)))) {
                return(i + 1);
            }
        }

        return(0);
    }

    function isAirlineFunded(address _airline) public view requireIsOperational returns (bool success) {
        return airlines[_airline].funds >= registration;
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (  
                                address _airline,
                                uint256 _fund  
                            )
                            public
                            payable
                            requireIsOperational
    {
        airlines[_airline].funds = airlines[_airline].funds.add(_fund);
        balance = balance.add(_fund);
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        balance = balance.add(msg.value);    }

        /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    /*function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner
                             
    {
        require(mode != operational, "New mode must be different from existing mode");
        require(authorizedCallers[msg.sender] == 1, "Caller is not an admin"); //check if authorized caller/registered airline

        bool isDuplicate = false;
        for(uint c=0; c<noOfAuthCallers; c++) {
            if (authorizedCallers[msg.sender] == 1) {
                isDuplicate = true;
                break;
            }
        }
        require(!isDuplicate, "Caller has already called this function.");

        authorizedCallers[msg.sender] == 1;
        if (noOfAuthCallers >= M) {
            operational = mode;           
        }
    }*/


}

