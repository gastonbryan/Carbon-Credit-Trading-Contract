
import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const address3 = accounts.get("wallet_3")!;
const deployer = accounts.get("deployer")!;

const contractName = "Carbon-Credit-Trading-Contract";

describe("Carbon Credit Trading Contract", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  describe("Carbon Credit Auditing System", () => {
    it("should authorize auditors correctly", () => {
      const certifications = ["ISO14001", "VCS", "CDM"];
      const { result } = simnet.callPublicFn(
        contractName,
        "authorize-auditor",
        [Cl.principal(address1), Cl.list(certifications.map(c => Cl.stringAscii(c)))],
        deployer
      );
      expect(result).toBeOk(Cl.bool(true));

      const isAuth = simnet.callReadOnlyFn(
        contractName,
        "is-authorized-auditor",
        [Cl.principal(address1)],
        deployer
      );
      expect(isAuth.result).toBeBool(true);
    });

    it("should prevent non-owners from authorizing auditors", () => {
      const certifications = ["ISO14001"];
      const { result } = simnet.callPublicFn(
        contractName,
        "authorize-auditor",
        [Cl.principal(address2), Cl.list(certifications.map(c => Cl.stringAscii(c)))],
        address1
      );
      expect(result).toBeErr(Cl.uint(100)); // err-owner-only
    });

    it("should initiate audit for existing credits", () => {
      // Setup: Authorize issuer and auditor
      simnet.callPublicFn(contractName, "authorize-issuer", [Cl.principal(address1)], deployer);
      const certifications = ["ISO14001", "VCS"];
      simnet.callPublicFn(
        contractName,
        "authorize-auditor",
        [Cl.principal(address2), Cl.list(certifications.map(c => Cl.stringAscii(c)))],
        deployer
      );

      // Issue a credit
      const issueResult = simnet.callPublicFn(
        contractName,
        "issue-credits",
        [Cl.uint(1000), Cl.stringAscii("FOREST-001"), Cl.uint(2023)],
        address1
      );
      expect(issueResult.result).toBeOk(Cl.uint(1));

      // Initiate audit
      const { result } = simnet.callPublicFn(
        contractName,
        "initiate-audit",
        [Cl.uint(1)],
        address2
      );
      expect(result).toBeOk(Cl.uint(1));
    });

  it("should complete audit successfully", () => {
      simnet.callPublicFn(contractName, "authorize-issuer", [Cl.principal(address1)], deployer);
      const certifications = ["ISO14001", "VCS"];
      simnet.callPublicFn(
        contractName,
        "authorize-auditor",
        [Cl.principal(address2), Cl.list(certifications.map(c => Cl.stringAscii(c)))],
        deployer
      );
      simnet.callPublicFn(
        contractName,
        "issue-credits",
        [Cl.uint(1000), Cl.stringAscii("FOREST-002"), Cl.uint(2023)],
        address1
      );
      simnet.callPublicFn(
        contractName,
        "initiate-audit",
        [Cl.uint(1)],
        address2
      );
      const { result } = simnet.callPublicFn(
        contractName,
        "complete-audit",
        [
          Cl.uint(1),
          Cl.stringAscii("Credit meets all environmental standards. Forest project verified with satellite imagery."),
          Cl.uint(95),
          Cl.stringAscii("excellent")
        ],
        address2
      );
      expect(result).toBeOk(Cl.bool(true));
    });

  it("should issue compliance certificates for high-quality audits", () => {
      simnet.callPublicFn(contractName, "authorize-issuer", [Cl.principal(address1)], deployer);
      const certs = ["ISO14001", "VCS"];
      simnet.callPublicFn(
        contractName,
        "authorize-auditor",
        [Cl.principal(address2), Cl.list(certs.map(c => Cl.stringAscii(c)))],
        deployer
      );
      simnet.callPublicFn(
        contractName,
        "issue-credits",
        [Cl.uint(1000), Cl.stringAscii("FOREST-003"), Cl.uint(2023)],
        address1
      );
      simnet.callPublicFn(
        contractName,
        "initiate-audit",
        [Cl.uint(1)],
        address2
      );
      simnet.callPublicFn(
        contractName,
        "complete-audit",
        [
          Cl.uint(1),
          Cl.stringAscii("Meets environmental standards"),
          Cl.uint(90),
          Cl.stringAscii("excellent")
        ],
        address2
      );
      const { result } = simnet.callPublicFn(
        contractName,
        "issue-compliance-certificate",
        [
          Cl.uint(1),
          Cl.uint(26280),
          Cl.stringAscii("CERT123ABC456DEF789GHI012JKL345MNO678PQR901STU234VWX567YZA890BCD"),
          Cl.stringAscii("A+")
        ],
        address2
      );
      expect(result).toBeOk(Cl.uint(1));

      const isValid = simnet.callReadOnlyFn(
        contractName,
        "is-certificate-valid",
        [Cl.uint(1)],
        deployer
      );
      expect(isValid.result).toBeBool(true);
    });

  it("should get audit statistics", () => {
      const ro = simnet.callReadOnlyFn(
        contractName,
        "get-audit-statistics",
        [],
        deployer
      );
      expect(ro.result).toBeDefined();
    });

  it("should get enhanced contract stats including audit data", () => {
      const ro = simnet.callReadOnlyFn(
        contractName,
        "get-contract-stats",
        [],
        deployer
      );
      expect(ro.result).toBeDefined();
    });
  });
});
