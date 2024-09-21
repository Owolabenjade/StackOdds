## **Sports Betting Smart Contract on Stacks Blockchain**

### **Introduction**
This smart contract implements a decentralized sports betting platform on the Stacks blockchain using the Clarity language. It provides a transparent and secure system for managing bets, calculating odds, and distributing payouts. The platform supports various bet types such as single bets, parlay bets, over/under, and point spread bets.

### **Features**
- **Multiple Bet Types**: Support for single, parlay, over/under, and point spread bets.
- **Dynamic Odds**: Real-time adjustment of odds based on the total amount staked on each outcome.
- **Tiered Payouts**: Payouts are calculated based on dynamic odds and the risk associated with each bet.
- **Oracle Integration**: Future enhancements will include integration with oracles for automated resolution of events.
- **Comprehensive Error Handling**: Edge cases and invalid inputs are managed with robust error handling.

### **Smart Contract Overview**
The contract consists of two primary data structures:
1. **betting-events**: Stores information about each event, including title, outcomes, total staked amounts, and the winning outcome.
2. **placed-bets**: Stores details of each placed bet, including bettor address, bet amount, chosen outcome, and bet type.

### **Functionality**

#### **Creating Events**
To create a new betting event:
- Use the `create-betting-event` function.
- Parameters: 
  - `title`: Title of the sporting event.
  - `outcomes`: A list of possible outcomes (e.g., ["Team A", "Team B"]).
  - `point-spread` (optional): The point spread value for the event.
  - `total-score` (optional): The expected total score for over/under bets.
- This function initializes a new event with zero staked amounts.

#### **Placing Bets**
To place a bet on an event:
- Use the `place-bet-on-event` function.
- Parameters:
  - `event-id`: The ID of the event on which to place a bet.
  - `selected-outcome`: The chosen outcome (e.g., "Team A").
  - `bet-type`: Type of the bet (e.g., "single", "parlay", "over/under", "point-spread").
  - `bet-details` (optional): Additional information such as combined event IDs for parlay bets or over/under threshold.
- The function updates the total staked amount and the amount staked on the selected outcome.

#### **Resolving Events**
To resolve an event and declare a winning outcome:
- Use the `resolve-betting-event` function.
- Parameters:
  - `event-id`: The ID of the event to be resolved.
  - `winning-outcome`: The winning outcome of the event.
  - `total-score` (optional): The final total score for over/under bets.
- Only the contract owner can call this function.

#### **Claiming Winnings**
To claim winnings from a resolved bet:
- Use the `claim-bet-winnings` function.
- Parameters:
  - `bet-id`: The ID of the bet to claim winnings for.
- The function calculates the payout based on the bet type and chosen outcome, and transfers the winnings to the bettor.

### **Supported Bet Types**
1. **Single Bets**: Betting on one outcome of a single event.
2. **Parlay Bets**: A combination of multiple single bets. All bets must win for the parlay to succeed.
3. **Over/Under Bets**: Betting on whether the total score will be over or under a specified threshold.
4. **Point Spread Bets**: Betting on the margin of victory. The bet wins if the chosen team "covers the spread."

### **Dynamic Odds and Payouts**
- **Odds Calculation**: The odds for each outcome are calculated as the ratio of the total staked amount to the amount staked on the specific outcome.
- **Tiered Payouts**: Payouts are adjusted based on the calculated odds, considering the risk and total pool size.

### **Data Structures**
1. **`betting-events` Map**:
   - `event-id`: Unique identifier for the event.
   - `event-title`: Name of the event.
   - `possible-outcomes`: List of possible outcomes.
   - `event-resolved`: Boolean indicating whether the event is resolved.
   - `winning-outcome`: The winning outcome of the event.
   - `total-score`: The final total score for over/under bets.
   - `point-spread`: The point spread value for point spread bets.
   - `total-staked`: Total amount staked on the event.
   - `outcome-staked`: Map of amounts staked on each outcome.

2. **`placed-bets` Map**:
   - `bet-id`: Unique identifier for the bet.
   - `associated-event-id`: ID of the associated event.
   - `bettor-address`: Address of the bettor.
   - `bet-amount`: Amount staked by the bettor.
   - `chosen-outcome`: The outcome chosen by the bettor.
   - `bet-type`: Type of the bet (single, parlay, etc.).
   - `bet-details`: Additional information for complex bets.
   - `payout-claimed`: Boolean indicating whether the winnings have been claimed.

### **Deployment and Usage**
1. **Deployment**:
   - Deploy the contract on the Stacks blockchain using the Clarity language.
   - Set the contract owner as the account that controls event resolution.

2. **Usage**:
   - Users can create events, place bets, resolve events, and claim winnings using the appropriate functions.
   - The contract owner is responsible for resolving events and declaring the winning outcome.

### **Security Considerations**
- **Access Control**: Only the contract owner can resolve events and declare winners.
- **Oracle Integration**: Future enhancements will include oracle integration to automate event resolution.
- **Error Handling**: The contract includes comprehensive error handling for invalid inputs and edge cases.
- **Reentrancy Guard**: Ensure no reentrancy attacks by carefully managing state changes before transferring funds.

### **Future Enhancements**
- **Oracle Integration**: Automate event resolution using reliable oracles.
- **User-Generated Events**: Allow trusted users to create their own events.
- **Betting Pools**: Implement shared betting pools and community-driven betting options.
- **NFT Integration**: Issue NFTs as proof of winning bets or participation.