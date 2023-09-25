# 🏛️⚡️ Spark Gov Relay 🏛️⚡️
This repository contains infrastructure necessary to process cross-chain execution of governance proposals.

The codebase uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework. In order to run tests, deploy contracts, or perform other operations, use standard [Foundry](https://github.com/foundry-rs/foundry) commands.

## ⚙️ Components
### 🔊 Forwarders
Forwarders are contracts on the host domain, where the governance of the protocol resides. <br>These contracts abstract away all complexity of using a bridge and facilitate seamless message passing between domains. <br>Host domain admin uses forwarders to trigger payload executions on a bridged chains.
### 🚦 Executors
Executors are serving as admins of the bridged domain instances of the protocol. <br>They are responsible for storying the queue of proposals passed from the host domain governance and their execution. <br> They manage bridged domain protocol instance using standard payload pattern.
## ✍️ Architecture Diagram
![Architecture Diagram](/diagram.png)
