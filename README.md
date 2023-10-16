# 🏛️⚡️ Spark Gov Relay 🏛️⚡️
This repository contains infrastructure necessary to process cross-chain execution of governance proposals.

The codebase uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework. In order to run tests, deploy contracts, or perform other operations, use standard [Foundry](https://github.com/foundry-rs/foundry) commands.

## ⚙️ Components
### 🚦 Executors
Executors serve as admins of the bridged domain instances of the protocol. <br>They are responsible for storying the queue of proposals passed from the host domain governance and their execution. <br> They manage bridged domain protocol instance using standard payload pattern.
## ✍️ Architecture Diagram
![Architecture Diagram](/diagram.png)
## 🤝 Contribution Guidelines
In order to add governance relay infrastructure for a new domain, perform the following steps:
1. Go to [XChain Helpers](https://github.com/marsfoundation/xchain-helpers) repository and add:
    1. A domain helper abstracting away the process of passing messages between host domain and your bridged domain.
    2. A helper function to the XChainForwarders library abstracting away host domain interactions with the bridge.
2. Add `BridgeExecutor` to the `/src/executors` directory. Follow currently used naming convention.
3. Add a new test file for your domain to the `/test` directory. Inherit `CrosschainTestBase` and add tests specific to your domain to the test suite. All of the tests have to pass. Follow linting and naming convention used in other test files.
4. Use proper labeling for your open PR (always set adequate priority and status)
5. Get an approving review from at least one of three designated reviewers - **@hexonaut**, **@lucas-manuel** or **@barrutko**
6. Enjoy governance messages being passed through the bridge to your domain! 🎉

***
*The IP in this repository was assigned to Mars SPC Limited in respect of the MarsOne SP*
