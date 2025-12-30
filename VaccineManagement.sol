// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VaccineManagement {
    address public regulatoryAuthority;
    bool public isManufacturerApproved;

    struct Manufacturer {
        uint rating;
        bool isApproved;
    }

    struct Trader {
        uint rating;
        bool isRegistered;
    }

    struct TemperatureData {
        uint timestamp;
        int8 temperature; // Using int8 to represent temperature in Celsius
        bytes32 dataHash;
    }

    struct ConsumerRequest {
        address consumer;
        uint timestamp;
        string request;
    }

    struct Feedback {
        address consumer;
        uint rating;
        string comments;
    }

    struct GrantedInformation {
        uint timestamp;
        string information;
    }

    mapping(address => Manufacturer) public manufacturers;
    mapping(address => Trader) public traders;
    mapping(address => TemperatureData[]) public temperatureRecords;
    mapping(address => ConsumerRequest[]) public consumerRequests;
    mapping(address => Feedback[]) public feedbacks;
    mapping(address => GrantedInformation[]) public grantedInformation;

    event ApprovalRequested(address indexed manufacturer, uint rating);
    event ApprovalGranted(address indexed manufacturer);
    event ApprovalRejected(address indexed manufacturer);
    event QualityImprovementNeeded(address indexed manufacturer, uint rating);
    event AddressGranted(address indexed manufacturer, address indexed manufacturerAddress);
    
    event RegistrationRequested(address indexed trader, uint rating);
    event RegistrationApproved(address indexed trader);
    event RegistrationRejected(address indexed trader);

    event TemperatureRecorded(address indexed sensor, uint timestamp, int8 temperature, bytes32 dataHash);
    event TemperatureOutOfRange(address indexed sensor, uint timestamp, int8 temperature);
    event TemperatureWithinRange(address indexed sensor, uint timestamp, int8 temperature);

    event RequestSubmitted(address indexed consumer, uint timestamp, string request);
    event InformationGranted(address indexed consumer, uint timestamp, string information);
    event FeedbackSubmitted(address indexed consumer, uint rating, string comments);

    constructor() {
        regulatoryAuthority = msg.sender;
        isManufacturerApproved = false;
    }

    modifier onlyRegulatoryAuthority() {
        require(msg.sender == regulatoryAuthority, "Only regulatory authority can perform this action");
        _;
    }

    modifier onlyWhenManufacturerApproved() {
        require(isManufacturerApproved, "No suitable manufacturers are registered");
        _;
    }

    // Manufacturer approval functions
    function requestApproval(uint _rating) external {
        require(_rating > 0, "Rating must be greater than 0");
        manufacturers[msg.sender].rating = _rating;
        emit ApprovalRequested(msg.sender, _rating);

        if (_rating >= 5) {
            grantApproval(msg.sender);
        } else if (_rating > 0 && _rating < 5) {
            emit QualityImprovementNeeded(msg.sender, _rating);
        }
    }

    function grantApproval(address _manufacturer) internal onlyRegulatoryAuthority {
        manufacturers[_manufacturer].isApproved = true;
        isManufacturerApproved = true;
        emit ApprovalGranted(_manufacturer);
        emit AddressGranted(_manufacturer, _manufacturer);
    }

    function rejectApproval(address _manufacturer) external onlyRegulatoryAuthority {
        manufacturers[_manufacturer].isApproved = false;
        emit ApprovalRejected(_manufacturer);
    }

    // Trader registration functions
    function requestTraderRegistration(uint _rating) external onlyWhenManufacturerApproved {
        require(_rating > 0, "Rating must be greater than 0");
        traders[msg.sender].rating = _rating;
        emit RegistrationRequested(msg.sender, _rating);
    }

    function approveTraderRegistration(address _trader) external onlyRegulatoryAuthority onlyWhenManufacturerApproved {
        require(traders[_trader].rating > 5, "Trader rating is below the required threshold");
        traders[_trader].isRegistered = true;
        emit RegistrationApproved(_trader);
    }

    function rejectTraderRegistration(address _trader) external onlyRegulatoryAuthority onlyWhenManufacturerApproved {
        traders[_trader].isRegistered = false;
        emit RegistrationRejected(_trader);
    }

    function isTraderRegistered(address _trader) external view returns (bool) {
        return traders[_trader].isRegistered;
    }

    // Temperature monitoring functions
    function recordTemperature(int8 _temperature) external {
        require(_temperature >= -30 && _temperature <= 50, "Temperature must be within realistic range for storage");

        uint timestamp = block.timestamp;
        bytes32 dataHash = keccak256(abi.encodePacked(msg.sender, timestamp, _temperature));

        TemperatureData memory newRecord = TemperatureData({
            timestamp: timestamp,
            temperature: _temperature,
            dataHash: dataHash
        });

        temperatureRecords[msg.sender].push(newRecord);

        emit TemperatureRecorded(msg.sender, timestamp, _temperature, dataHash);

        if (_temperature < 2 || _temperature > 8) {
            emit TemperatureOutOfRange(msg.sender, timestamp, _temperature);
        } else {
            emit TemperatureWithinRange(msg.sender, timestamp, _temperature);
        }
    }

    function verifyTemperature(address _sensor, uint _index) external view returns (bool, string memory) {
        require(_index < temperatureRecords[_sensor].length, "Invalid temperature record index");

        TemperatureData memory record = temperatureRecords[_sensor][_index];
        
        if (record.temperature < 2 || record.temperature > 8) {
            return (false, "Temperature is out of the required range");
        } else {
            return (true, "Temperature is within the required range");
        }
    }

    function getTemperatureRecord(address _sensor, uint _index) external view returns (uint, int8, bytes32) {
        require(_index < temperatureRecords[_sensor].length, "Invalid temperature record index");

        TemperatureData memory record = temperatureRecords[_sensor][_index];
        return (record.timestamp, record.temperature, record.dataHash);
    }

    // Consumer interaction functions
    function submitRequest(string memory _request) external {
        ConsumerRequest memory newRequest = ConsumerRequest({
            consumer: msg.sender,
            timestamp: block.timestamp,
            request: _request
        });

        consumerRequests[msg.sender].push(newRequest);
        emit RequestSubmitted(msg.sender, block.timestamp, _request);
    }

    function grantInformation(address _consumer, string memory _information) external onlyRegulatoryAuthority {
        require(consumerRequests[_consumer].length > 0, "No requests from this consumer");

        GrantedInformation memory newInfo = GrantedInformation({
            timestamp: block.timestamp,
            information: _information
        });

        grantedInformation[_consumer].push(newInfo);
        emit InformationGranted(_consumer, block.timestamp, _information);
    }

    function submitFeedback(uint _rating, string memory _comments) external {
        Feedback memory newFeedback = Feedback({
            consumer: msg.sender,
            rating: _rating,
            comments: _comments
        });

        feedbacks[msg.sender].push(newFeedback);
        emit FeedbackSubmitted(msg.sender, _rating, _comments);
    }

    function getConsumerRequests(address _consumer) external view returns (ConsumerRequest[] memory) {
        return consumerRequests[_consumer];
    }

    function getFeedbacks(address _consumer) external view returns (Feedback[] memory) {
        return feedbacks[_consumer];
    }

    function getGrantedInformation(address _consumer) external view returns (GrantedInformation[] memory) {
        return grantedInformation[_consumer];
    }
}
