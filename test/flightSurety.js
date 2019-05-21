
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });
  /*
  it(`(passenger) can withdraw ones insurance`, async function () {

    let passenger = accounts[2];
    await config.flightSuretyApp.buy(1 , "Flight no1", { from: passenger });
    await config.flightSuretyApp.pay({ from: passenger });
    let transffunds = await config.flightSuretyApp.getPassengersInsurance({ from: passenger});
    console.log(transffunds);
    assert.equal(transffunds, 1, "Funds are not transfered.")
            
  });*/

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

    await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try {
            await config.flightSurety.setTestingMode(true);
        } catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(multiparty) only existing airline may register a new airline until there are at least four airlines registered', async () => {

        // ARRANGE
        let newAirline = accounts[2];

        let funds = 10000000000000000000; // 10 ether

        try{
          await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
        }
        catch(e) {

        }
        let result = await config.flightSuretyData.isAirlineRegistered(newAirline);

        await config.flightSuretyApp.sendFundToAirline(config.firstAirline, {from: config.firstAirline, value: funds}); 
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
        let result2 = await config.flightSuretyData.isAirlineRegistered(newAirline);

        assert.equal(result, false, "Airline was registered but it should not.");
        assert.equal(result2, true, "Airline was not registered but it should.");

    });
 
    it('(multiparty) registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airliner', async () => {

        // ARRANGE
        let newAirline = accounts[2];
        let newAirline2 = accounts[3];
        let newAirline3 = accounts[4];
        let newAirline4 = accounts[5];

        let funds = 10000000000000000000; // 10 ether

        await config.flightSuretyApp.registerAirline(newAirline2, {from: config.firstAirline});
        await config.flightSuretyApp.sendFundToAirline(newAirline2, {from: config.firstAirline, value: funds}); 
        await config.flightSuretyApp.registerAirline(newAirline3, {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(newAirline4, {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(newAirline4, {from: newAirline2});
        await config.flightSuretyApp.sendFundToAirline(newAirline4, {from: config.firstAirline, value: funds});

        let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline4);

        // ASSERT
        assert.equal(result, true, "Airline was not registered.");

    });


      it('(airline) airline can be registered, but does not participate in contract until it submits funding of 10 ether', async () => {

        // ARRANGE
        let newAirline = accounts[6];
        let newAirline2 = accounts[3];
        let testAirline = accounts[7];

        let funds = 10000000000000000000; // 10 ether

        await config.flightSuretyApp.sendFundToAirline(config.firstAirline, {from: config.firstAirline, value: funds}); 
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(newAirline, {from: newAirline2});
        let result = await config.flightSuretyData.isAirlineRegistered(newAirline);

        //check if this can register a new airline (can participate in contract)

        let reverted = false;
        try {
            await config.flightSuretyApp.registerAirline(testAirline, {from: newAirline});
        } catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "New registered airline can participate without funds.");

        assert.equal(result, true, "Airline was registered but it should not.");
        //assert.equal(result2, true, "Airline was not registered but it should.");

    });

});
