YieldVault
==========

* * * * *

📄 Overview
-----------

YieldVault is a smart contract for automated, on-chain yield optimization. It uses a built-in machine learning (ML) model to intelligently analyze market data, predict the highest-yielding DeFi strategies, and automatically rebalance the portfolio. The goal is to provide users with **maximum returns** while managing risk through a data-driven approach.

This README provides a comprehensive guide to the contract's architecture, functions, and key features. It is intended for developers, auditors, and users who want to understand the inner workings of the YieldVault protocol.

* * * * *

💻 Features
-----------

### Intelligent Yield Optimization

The core of YieldVault's functionality is its **on-chain ML model**. This model is designed to learn from historical performance data, market conditions, and risk metrics. It's not a traditional off-chain oracle; the entire training and prediction process happens directly on the blockchain, ensuring a high degree of transparency and security. The model analyzes various features to predict the optimal yield for each available strategy.

### Automated Rebalancing

The `ml-rebalance-portfolio` function is the protocol's engine. Triggered by the contract owner, it executes a sophisticated rebalancing algorithm. This algorithm:

1.  **Generates predictions** for all active yield strategies using the trained ML model.

2.  **Assesses risk** for each strategy dynamically, penalizing those with high volatility.

3.  **Calculates optimal allocations** based on the predicted yield and a specified risk tolerance.

4.  **Executes the rebalance** by updating the total allocated funds for each strategy.

This process ensures that the portfolio is always aligned with the most profitable and risk-appropriate opportunities identified by the ML model.

### Dynamic Risk Assessment

Every yield strategy in the vault is continuously assessed for risk. The `assess-strategy-risk` private function calculates a risk score based on the strategy's current APY relative to its historical performance. This allows the rebalancing function to prioritize stable, high-yield options and avoid overly speculative or volatile ones, directly contributing to a safer user experience.

* * * * *

🛠️ Functions
-------------

### Public Functions

| Function Name | Description |
| --- | --- |
| `(add-yield-strategy (name (string-ascii 50)) (initial-apy uint) (risk-score uint))` | Adds a new yield strategy to the vault, expanding the investment options. Only the contract owner can call this function. |
| `(deposit (amount uint))` | Allows users to deposit funds into the contract. Shares are automatically minted and calculated based on the current total funds and total shares, ensuring a fair entry price for all depositors. |
| `(predict-strategy-yield (strategy-id uint) (market-features (list 10 uint)))` | A public endpoint for querying the ML model's prediction for a specific strategy, based on current market features. This function requires the model to be trained and the prediction confidence to be above a set threshold. |
| `(train-model (training-data (list 20 {features: (list 10 uint), target: uint})))` | Trains the on-chain ML model using a list of historical data points. This is a critical owner-only function that must be performed regularly to keep the model's predictions accurate. |
| `(toggle-pause)` | An emergency function that allows the owner to pause or unpause the contract. This can be used to prevent new deposits or rebalances in the event of a critical vulnerability or market crash. |
| `(ml-rebalance-portfolio (market-conditions (list 10 uint)) (risk-tolerance uint))` | The primary function for reallocating the portfolio's funds. It uses ML predictions to determine the best allocation percentages for each strategy, aiming for optimal returns within the specified risk tolerance. |

### Private Functions

| Function Name | Description |
| --- | --- |
| `(is-owner)` | Checks if the transaction sender is the contract owner. This is used as an assertion guard for all owner-only functions. |
| `(not-paused)` | Verifies that the contract is not in a paused state, preventing unauthorized activity. |
| `(calculate-weighted-prediction (features (list 10 uint)))` | The core of the ML model's inference. This function takes a list of features and uses the stored model weights to compute a predicted yield. |
| `(calculate-feature-contribution (feature-value uint) (accumulator uint))` | A helper function used within `calculate-weighted-prediction` to sum the weighted contribution of each feature to the final prediction. |
| `(update-model-accuracy (predicted uint) (actual uint))` | A post-rebalance function that updates the model's overall accuracy score by comparing its prediction to the actual yield achieved. This metric is used to enforce a minimum prediction confidence. |
| `(assess-strategy-risk (strategy-id uint))` | Determines a risk score for a given strategy by comparing its current APY to its historical performance, helping to identify and avoid high-volatility investments. |
| `(generate-strategy-prediction (strategy-id uint) (context ...))` | A helper function used by `ml-rebalance-portfolio` to iterate through all strategies and generate a predicted yield and risk score for each. |
| `(calculate-optimal-allocation (prediction ...) (context ...))` | A helper function that takes a strategy's prediction and calculates the optimal percentage of funds to be allocated to it, considering risk tolerance and yield. |
| `(execute-rebalancing (allocation ...) (context ...))` | The final helper function that performs the actual rebalancing by updating the allocation and total allocated funds for a given strategy. |
| `(assess-portfolio-risk (allocations ...))` | Calculates the weighted average risk score for the entire portfolio after a rebalance, providing a snapshot of the current risk level. |

### Read-Only Functions

| Function Name | Description |
| --- | --- |
| `(get-user-portfolio-value (user principal))` | Returns the current value of a user's portfolio in the vault, calculated by multiplying their share count by the current share price. |

* * * * *

📦 Data Structures
------------------

-   `user-deposits`: A map that tracks the total funds deposited by each user principal.

-   `user-shares`: A map that stores the number of shares held by each user, representing their proportional ownership of the vault.

-   `yield-strategies`: A map detailing each yield strategy, including its name, current APY, risk score, and allocation percentage.

-   `model-weights`: A map storing the weights of the ML model's features. These weights are updated during model training.

-   `historical-data`: A map for storing historical data points used to train the ML model. This data is crucial for the model's accuracy.

* * * * *

⚠️ Error Codes
--------------

| Code | Description |
| --- | --- |
| `u100` | **`err-owner-only`**: Unauthorized access; a function was called by a non-owner. |
| `u101` | **`err-insufficient-balance`**: The specified amount is zero or a user's balance is too low for the requested operation. |
| `u102` | **`err-invalid-strategy`**: An invalid strategy ID or an error in a strategy's configuration was detected. |
| `u103` | **`err-contract-paused`**: The contract is currently in a paused state, preventing deposits, rebalancing, and other key functions. |
| `u104` | **`err-invalid-prediction`**: The ML model's prediction confidence is below the set threshold, making the result unreliable. |
| `u105` | **`err-model-not-trained`**: The ML model has not been trained yet, or its training data is insufficient. |
| `u106` | **`err-insufficient-data`**: Not enough data samples are provided to train the ML model. |

* * * * *

⚖️ License
----------

This project is licensed under the MIT License.

* * * * *

🤝 Contribution
---------------

Contributions are welcome! If you have suggestions for improving the on-chain ML model, optimizing the rebalancing algorithm, or adding new features, please open an issue or submit a pull request.

* * * * *

🔗 Related Resources
--------------------

-   [Stacks.js Library](https://www.google.com/search?q=https://github.com/hirosystems/stacks.js)

-   [Stacks Documentation](https://docs.stacks.co/)
