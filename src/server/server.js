import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json'; 
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json'; 
import Config from './config.json'; 
import Web3 from 'web3'; 
import express from 'express'; 
let config = Config['localhost']; 
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws'))); 
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress); 
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

let oracles = [];

let STATUS_CODES = [{
    "label": "STATUS_CODE_UNKNOWN",
    "code": 0
}, {
    "label": "STATUS_CODE_ON_TIME",
    "code": 10
}, {
    "label": "STATUS_CODE_LATE_AIRLINE",
    "code": 20
}, {
    "label": "STATUS_CODE_LATE_WEATHER",
    "code": 30
}, {
    "label": "STATUS_CODE_LATE_TECHNICAL",
    "code": 40
}, {
    "label": "STATUS_CODE_LATE_OTHER",
    "code": 50
}];


async function test() {
    let fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
    let accounts = await web3.eth.getAccounts();
    console.log(accounts);
    accounts.forEach(async account => {
        let r = await flightSuretyApp.methods.registerOracle().send({
            "from": account,
            "value": fee,
            "gas": 47123880000,
            "gasPrice": 100000
        });
        let result = await flightSuretyApp.methods.getMyIndexes.call({from: account});
        console.log(result);
        console.log(`Oracle ${account} registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    });
}

test();

flightSuretyApp.events.OracleRequest({ 
    fromBlock: "latest" }, async function (error, event) { 
        if (error) { 
            console.log(error); 
        } 

    let airline = event.returnValues.airline; 
    let flight = event.returnValues.flight;
    let timestamp = event.returnValues.timestamp; 
    let found = false;

    let selectedCode = STATUS_CODES[1];
    let scheduledTime = (timestamp * 1000);
    console.log(`Flight scheduled to: ${new Date(scheduledTime)}`);
    if (scheduledTime < Date.now()) {
        selectedCode = STATUS_CODES[2];
    }

    oracles.forEach((oracle, index) => {
        if (found) {
            return false;
        }
        for(let idx = 0; idx < 3; idx += 1) {
            if (found) {
                break;
            }
            if (selectedCode.code === 20) {
                console.log("WILL COVER USERS");
                flightSuretyApp.methods.creditInsurees(
                    accounts[index],
                    flight
                ).send({
                    from: accounts[index]
                }).then(result => {
                    //console.log(result);
                    console.log(`Flight ${flight} got covered and insured the users`);
                }).catch(err => {
                    console.log(err.message);
                });
            }
            flightSuretyApp.methods.submitOracleResponse(
                oracle[idx], airline, flight, timestamp, selectedCode.code
            ).send({
                from: accounts[index]
            }).then(result => {
                found = true;
                console.log(`Oracle: ${oracle[idx]} responded from flight ${flight} with status ${selectedCode.code} - ${selectedCode.label}`);
            }).catch(err => {
                console.log(err.message);
            });
        }
    });
});


const app = express(); app.get('/api', (req, res) => { res.send({ message: 'An API for use with your Dapp!' }); });

export default app;