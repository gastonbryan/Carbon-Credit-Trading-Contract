import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const seller = accounts.get("wallet_1")!;
const buyer = accounts.get("wallet_2")!;
const royaltyRecipient = accounts.get("wallet_3")!;

const contractName = "Carbon-Credit-Trading-Contract";

describe("Royalty Feature", () => {
  it("should configure and apply royalties on marketplace purchases", () => {
    simnet.callPublicFn(contractName, "authorize-issuer", [Cl.principal(seller)], deployer);
    
    simnet.callPublicFn(
      contractName,
      "issue-credits",
      [Cl.uint(1000), Cl.stringAscii("SOLAR-001"), Cl.uint(2024)],
      seller
    );

    const listingResult = simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(1), Cl.uint(10000000), Cl.uint(1000)],
      seller
    );
    expect(listingResult.result).toBeOk(Cl.uint(1));

    simnet.callPublicFn(
      contractName,
      "set-royalty-bps",
      [Cl.uint(500)],
      deployer
    );

    simnet.callPublicFn(
      contractName,
      "set-royalty-recipient",
      [Cl.principal(royaltyRecipient)],
      deployer
    );

    const royaltyBps = simnet.callReadOnlyFn(
      contractName,
      "get-royalty-bps",
      [],
      deployer
    );
    expect(royaltyBps.result).toBeUint(500);

    const calculatedRoyalty = simnet.callReadOnlyFn(
      contractName,
      "calculate-royalty",
      [Cl.uint(10000000)],
      deployer
    );
    expect(calculatedRoyalty.result).toBeUint(500000);

    const purchaseResult = simnet.callPublicFn(
      contractName,
      "buy-credits-with-royalty",
      [Cl.uint(1)],
      buyer
    );
    expect(purchaseResult.result).toBeOk(Cl.uint(1));

    const recipientInfo = simnet.callReadOnlyFn(
      contractName,
      "get-royalty-recipient",
      [],
      deployer
    );
    expect(recipientInfo.result).toBePrincipal(royaltyRecipient);
  });
});
