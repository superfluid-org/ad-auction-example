// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AdSpotContract} from "../src/AdSpotContract.sol";
import {
    SuperfluidFrameworkDeployer
} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.t.sol";
import {
    SuperTokenV1Library,
    ISuperToken,
    ISuperfluid
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {
    ERC1820RegistryCompiled
} from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";

contract AdSpotContractTest is Test {
    using SuperTokenV1Library for ISuperToken;

    AdSpotContract private adSpotContract;
    SuperfluidFrameworkDeployer.Framework private sf;
    ISuperToken private acceptedToken;

    address public account1;
    address public account2;

    function setUp() public {
        // Deploy ERC1820Registry
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);

        // Deploy framework
        SuperfluidFrameworkDeployer sfDeployer = new SuperfluidFrameworkDeployer();
        sfDeployer.deployTestFramework();
        sf = sfDeployer.getFramework();

        // Deploy and mint test tokens
        acceptedToken = sfDeployer.deployPureSuperToken("PureSuperToken", "PSUP", 100000000e18);

        // Deploy AdSpot contract
        adSpotContract = new AdSpotContract(acceptedToken);
        console.log("AdSpotContract deployed at:", address(adSpotContract));
        console.log("Pool deployed at:", adSpotContract.getPoolAddress());
        console.log("is whitelisting enabled:", sf.host.APP_WHITE_LISTING_ENABLED());
        console.log("isSuperApp:", sf.host.isApp(adSpotContract));

        // Setup test accounts
        account1 = address(0x72343b915f335B2af76CA703cF7a550C8701d5CD);
        account2 = address(0x61fFC0072D66cE2bC3b8D7654BF68690b2d7fDc4);

        // Fund accounts
        acceptedToken.transfer(address(adSpotContract), 1000000e18);
        acceptedToken.transfer(account1, 1000000e18);
        acceptedToken.transfer(account2, 1000000e18);

        // Initial transfer to contract
        vm.prank(account1);
        acceptedToken.transfer(address(adSpotContract), 1e18);
    }

    function testInitialSetup() public view {
        assertEq(address(adSpotContract.getAcceptedToken()), address(acceptedToken), "Accepted token should match");
        assertEq(adSpotContract.getOwner(), address(this), "Contract owner should be this contract");
        assertEq(adSpotContract.getHighestBidder(), address(0), "Initial highest bidder should be address 0");
    }

    function testFlowCreation() public {
        int96 flowRate = int96(10000);

        vm.startPrank(account1);
        acceptedToken.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");
    }

    function testFlowUpdate() public {
        int96 flowRate = int96(1000);

        vm.startPrank(account1);
        acceptedToken.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        vm.startPrank(account1);
        acceptedToken.updateFlow(address(adSpotContract), 2 * flowRate);
        vm.stopPrank();

        assertEq(adSpotContract.getHighestFlowRate(), 2 * flowRate, "Highest flow rate should match the set flow rate");
    }

    function testFlowDeletion() public {
        int96 flowRate = int96(1000);

        vm.startPrank(account1);
        acceptedToken.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        vm.startPrank(account1);
        acceptedToken.deleteFlow(account1, address(adSpotContract));
        vm.stopPrank();

        assertEq(adSpotContract.getHighestBidder(), address(0), "Initial highest bidder should be address 0");
        assertEq(adSpotContract.getHighestFlowRate(), 0, "Highest flow rate should match the set flow rate");
    }

    function testHigherBidd() public {
        int96 flowRate = int96(1000);

        vm.startPrank(account1);
        acceptedToken.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        vm.startPrank(account2);
        acceptedToken.createFlow(address(adSpotContract), flowRate + 2);
        vm.stopPrank();

        assertEq(adSpotContract.getHighestBidder(), account2, "Account2 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate + 2, "Highest flow rate should match the set flow rate");
    }

    function testNFTSetting() public {
        int96 flowRate = int96(1000);

        vm.startPrank(account1);
        acceptedToken.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        vm.startPrank(account1);
        adSpotContract.setNftToShowcase(address(this), 1);
        vm.stopPrank();

        assertEq(adSpotContract.getNftAddress(), address(this), "NFT address should be this contract");
        assertEq(adSpotContract.getNftTokenId(), 1, "NFT token ID should be 1");
    }

    function testOwnerUnitsFirstTime() public {
        int96 flowRate = int96(1000);

        vm.startPrank(account1);
        acceptedToken.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        assertEq(adSpotContract.getOwnerShares(), 1, "Owner's shares should be 1");
    }

    function testMembersUnits() public {
        int96 flowRate = int96(1000);

        vm.startPrank(account1);
        acceptedToken.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        assertEq(adSpotContract.getOwnerShares(), 1, "Owner's shares should be 1");

        vm.startPrank(account2);
        acceptedToken.createFlow(address(adSpotContract), flowRate + 2);
        vm.stopPrank();

        assertEq(
            adSpotContract.getOwnerShares(),
            adSpotContract.getTotalShares() / 2,
            "Owner's shares should be half of total shares"
        );
        assertEq(
            adSpotContract.getOwnerShares(),
            adSpotContract.getMemberShares(account1),
            "Owner's shares should be same as account1's shares"
        );
    }

    function testAdvancedMembersUnits() public {
        int96 flowRate = int96(1000);

        vm.startPrank(account1);
        acceptedToken.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        assertEq(adSpotContract.getOwnerShares(), 1, "Owner's shares should be 1");

        vm.startPrank(account2);
        acceptedToken.createFlow(address(adSpotContract), flowRate + 2);
        vm.stopPrank();

        assertEq(
            adSpotContract.getOwnerShares(),
            adSpotContract.getTotalShares() / 2,
            "Owner's shares should be half of total shares"
        );
        assertEq(
            adSpotContract.getOwnerShares(),
            adSpotContract.getMemberShares(account1),
            "Owner's shares should be same as account1's shares"
        );

        vm.startPrank(account1);
        acceptedToken.createFlow(address(adSpotContract), flowRate + 4);
        vm.stopPrank();

        assertEq(
            adSpotContract.getOwnerShares(),
            adSpotContract.getTotalShares() / 2,
            "Owner's shares should be 1/3 of total shares"
        );
        assertEq(
            adSpotContract.getMemberShares(account1) + adSpotContract.getMemberShares(account2),
            adSpotContract.getTotalShares() / 2,
            "Owner's shares should be 1/3 of total shares"
        );
    }
}
