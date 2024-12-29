Here's a detailed `README.md` file for your **Dynamic Budget Allocation System** project:

```markdown
# Dynamic Budget Allocation System

The Dynamic Budget Allocation System is a Clarity smart contract designed to manage treasury funds and allocate budgets to projects dynamically. The contract allows a contract owner to initialize a treasury, allocate funds to projects, and track project budgets and performance scores. 

This system ensures controlled access and prevents unauthorized or invalid operations, making it suitable for decentralized budget management.

## Features

- **Treasury Initialization**: The contract owner can initialize the treasury with a specific amount.
- **Budget Allocation**: Funds can be allocated to specific projects along with an initial performance score.
- **Project Budget Tracking**: Track the balance and performance score for each project.
- **Controlled Access**: Only the contract owner can perform critical operations.
- **Error Handling**: Provides meaningful error messages for unauthorized or invalid operations.

## Smart Contract Structure

### Constants
- `ERR-NOT-AUTHORIZED`: Returned when a non-owner attempts an authorized action.
- `ERR-INVALID-AMOUNT`: Returned when an allocation exceeds the treasury balance.

### Data Variables
- `treasury-balance`: Tracks the current treasury balance.
- `total-allocations`: Tracks the total funds allocated so far.
- `contract-owner`: The principal address of the contract owner.

### Data Maps
- `budgets`: Maps project principals to their allocated budget and performance score.

### Public Functions
- **`initialize-treasury(amount uint)`**
  - Initializes the treasury with a specific amount.
  - **Requires**: Sender must be the contract owner.
  
- **`allocate-budget(project principal, amount uint, initial-score uint)`**
  - Allocates funds to a project with an initial performance score.
  - **Requires**: Sender must be the contract owner, and the amount must not exceed the treasury balance.

### Read-only Functions
- **`get-project-budget(project principal)`**
  - Returns the budget and performance score for a specific project.
  
- **`get-treasury-balance()`**
  - Returns the current treasury balance.

## Installation

1. Install the Clarity development environment using [Clarinet](https://docs.hiro.so/clarinet/getting-started).
2. Clone this repository:
   ```bash
   git clone <repository-url>
   cd dynamic-budget-allocation
   ```
3. Run the project locally:
   ```bash
   clarinet console
   ```

## Testing

Unit tests are written using [Vitest](https://vitest.dev/). To run the tests:

1. Ensure you have Node.js installed.
2. Install dependencies:
   ```bash
   npm install
   ```
3. Run tests:
   ```bash
   npm test
   ```

## Usage

1. **Deploy the contract**:
   - Use Clarinet to deploy the contract to your desired network.
   
2. **Initialize the Treasury**:
   - Call the `initialize-treasury` function with the desired initial amount.
   
3. **Allocate Budgets**:
   - Use the `allocate-budget` function to assign funds to specific projects.
   
4. **Query Data**:
   - Use the `get-project-budget` and `get-treasury-balance` functions to track budgets and treasury balance.

## Examples

### Initialize Treasury
```clarity
(initialize-treasury u1000)
```

### Allocate Budget
```clarity
(allocate-budget 'ST1234... u500 u80)
```

### Query Project Budget
```clarity
(get-project-budget 'ST1234...)
```

### Query Treasury Balance
```clarity
(get-treasury-balance)
```

## Error Codes

| Code                 | Description                                      |
|----------------------|--------------------------------------------------|
| `ERR-NOT-AUTHORIZED` | The sender is not authorized to perform this action. |
| `ERR-INVALID-AMOUNT` | The specified amount exceeds the treasury balance.  |

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.