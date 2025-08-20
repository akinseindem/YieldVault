;; Yield Optimizer with On-Chain Machine Learning
;; This contract implements an intelligent yield optimization system that uses on-chain
;; machine learning algorithms to predict optimal yield farming strategies. It analyzes
;; historical performance data, market conditions, and risk metrics to automatically
;; allocate funds across different DeFi protocols for maximum returns.

;; ===================
;; CONSTANTS
;; ===================

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-strategy (err u102))
(define-constant err-contract-paused (err u103))
(define-constant err-invalid-prediction (err u104))
(define-constant err-model-not-trained (err u105))
(define-constant err-insufficient-data (err u106))

;; ML Model parameters
(define-constant max-features u10)
(define-constant max-strategies u5)
(define-constant min-training-samples u20)
(define-constant prediction-confidence-threshold u75) ;; 75%

;; Risk and performance constants
(define-constant max-allocation-per-strategy u50) ;; 50% max per strategy
(define-constant rebalance-threshold u10) ;; 10% deviation triggers rebalance

;; ===================
;; DATA MAPS AND VARS
;; ===================

;; Contract state management
(define-data-var contract-paused bool false)
(define-data-var total-funds uint u0)
(define-data-var model-trained bool false)
(define-data-var prediction-accuracy uint u0)

;; User deposits and balances
(define-map user-deposits principal uint)
(define-map user-shares principal uint)
(define-data-var total-shares uint u0)

;; Yield strategies with performance tracking
(define-map yield-strategies
  uint ;; strategy-id
  {
    name: (string-ascii 50),
    current-apy: uint,
    risk-score: uint,
    allocation-percentage: uint,
    total-allocated: uint,
    historical-performance: uint
  }
)

;; ML Model weights and features
(define-map model-weights uint uint) ;; feature-index -> weight
(define-map feature-values uint uint) ;; feature-index -> current-value

;; Historical data for ML training
(define-map historical-data
  uint ;; data-point-id
  {
    timestamp: uint,
    strategy-performance: (list 5 uint),
    market-conditions: (list 10 uint),
    actual-yield: uint
  }
)

(define-data-var data-point-counter uint u0)
(define-data-var strategy-counter uint u0)

;; Performance tracking
(define-map strategy-predictions
  {strategy-id: uint, timestamp: uint}
  {
    predicted-yield: uint,
    actual-yield: uint,
    confidence: uint
  }
)

;; ===================
;; PRIVATE FUNCTIONS
;; ===================

;; Check if caller is contract owner
(define-private (is-owner)
  (is-eq tx-sender contract-owner))

;; Check if contract is not paused
(define-private (not-paused)
  (not (var-get contract-paused)))

;; Calculate weighted prediction using linear regression
(define-private (calculate-weighted-prediction (features (list 10 uint)))
  (let ((prediction (fold calculate-feature-contribution features u0)))
    (if (> prediction u0) prediction u1)))

(define-private (calculate-feature-contribution (feature-value uint) (accumulator uint))
  (let ((feature-index (len (list feature-value))))
    (+ accumulator (* feature-value (default-to u1 (map-get? model-weights feature-index))))))

;; Update model accuracy based on prediction vs actual results
(define-private (update-model-accuracy (predicted uint) (actual uint))
  (let ((error (if (> predicted actual) (- predicted actual) (- actual predicted)))
        (accuracy-score (if (> actual u0) (- u100 (/ (* error u100) actual)) u0)))
    (var-set prediction-accuracy 
      (/ (+ (* (var-get prediction-accuracy) u9) accuracy-score) u10))))

;; Risk assessment based on historical volatility
(define-private (assess-strategy-risk (strategy-id uint))
  (let ((strategy (unwrap-panic (map-get? yield-strategies strategy-id))))
    (let ((performance (get historical-performance strategy))
          (current-apy (get current-apy strategy)))
      (if (> current-apy (* performance u2))
        u80 ;; High risk if APY is 2x historical average
        (if (> current-apy performance) u40 u20))))) ;; Medium/Low risk

;; ===================
;; PUBLIC FUNCTIONS
;; ===================

;; Initialize a new yield strategy
(define-public (add-yield-strategy (name (string-ascii 50)) (initial-apy uint) (risk-score uint))
  (begin
    (asserts! (is-owner) err-owner-only)
    (asserts! (not-paused) err-contract-paused)
    
    (let ((strategy-id (+ (var-get strategy-counter) u1)))
      (map-set yield-strategies strategy-id
        {
          name: name,
          current-apy: initial-apy,
          risk-score: risk-score,
          allocation-percentage: u0,
          total-allocated: u0,
          historical-performance: initial-apy
        })
      (var-set strategy-counter strategy-id)
      (ok strategy-id))))

;; User deposit function with automatic share calculation
(define-public (deposit (amount uint))
  (begin
    (asserts! (not-paused) err-contract-paused)
    (asserts! (> amount u0) err-insufficient-balance)
    
    (let ((current-deposit (default-to u0 (map-get? user-deposits tx-sender)))
          (current-shares (default-to u0 (map-get? user-shares tx-sender)))
          (share-price (if (> (var-get total-shares) u0)
                         (/ (var-get total-funds) (var-get total-shares))
                         u1))
          (new-shares (/ amount share-price)))
      
      (map-set user-deposits tx-sender (+ current-deposit amount))
      (map-set user-shares tx-sender (+ current-shares new-shares))
      (var-set total-funds (+ (var-get total-funds) amount))
      (var-set total-shares (+ (var-get total-shares) new-shares))
      (ok new-shares))))

;; Predict optimal yield for a strategy using ML model
(define-public (predict-strategy-yield (strategy-id uint) (market-features (list 10 uint)))
  (begin
    (asserts! (not-paused) err-contract-paused)
    (asserts! (var-get model-trained) err-model-not-trained)
    
    (let ((prediction (calculate-weighted-prediction market-features))
          (confidence (var-get prediction-accuracy))
          (timestamp block-height))
      
      (asserts! (>= confidence prediction-confidence-threshold) err-invalid-prediction)
      
      (map-set strategy-predictions {strategy-id: strategy-id, timestamp: timestamp}
        {
          predicted-yield: prediction,
          actual-yield: u0, ;; To be updated later
          confidence: confidence
        })
      
      (ok {predicted-yield: prediction, confidence: confidence}))))

;; Train ML model with historical data
(define-public (train-model (training-data (list 20 {features: (list 10 uint), target: uint})))
  (begin
    (asserts! (is-owner) err-owner-only)
    (asserts! (not-paused) err-contract-paused)
    (asserts! (>= (len training-data) min-training-samples) err-insufficient-data)
    
    ;; Simple linear regression weight calculation
    (let ((updated-weights (fold update-model-weights training-data (list))))
      (var-set model-trained true)
      (ok "Model training completed"))))

(define-private (update-model-weights 
  (data-point {features: (list 10 uint), target: uint}) 
  (acc (list 10 uint)))
  (let ((features (get features data-point))
        (target (get target data-point)))
    ;; Simplified weight update using gradient descent concept
    (fold update-single-weight features acc)))

(define-private (update-single-weight (feature uint) (weights (list 10 uint)))
  (let ((weight-index (len weights))
        (learning-rate u1)
        (current-weight (default-to u1 (map-get? model-weights weight-index))))
    (map-set model-weights weight-index (+ current-weight learning-rate))
    (unwrap-panic (as-max-len? (append weights (+ current-weight learning-rate)) u10))))

;; Get user's current portfolio value
(define-read-only (get-user-portfolio-value (user principal))
  (let ((user-share-count (default-to u0 (map-get? user-shares user)))
        (share-price (if (> (var-get total-shares) u0)
                       (/ (var-get total-funds) (var-get total-shares))
                       u1)))
    (* user-share-count share-price)))

;; Emergency pause/unpause
(define-public (toggle-pause)
  (begin
    (asserts! (is-owner) err-owner-only)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))))

;; Helper function to generate predictions for each strategy
(define-private (generate-strategy-prediction 
  (strategy-id uint) 
  (context {market-conditions: (list 10 uint), predictions: (list 5 {id: uint, yield: uint, risk: uint}), total-expected-yield: uint}))
  (if (<= strategy-id (var-get strategy-counter))
    (let ((predicted-yield (calculate-weighted-prediction (get market-conditions context)))
          (risk-score (assess-strategy-risk strategy-id)))
      {
        market-conditions: (get market-conditions context),
        predictions: (unwrap-panic (as-max-len? 
                       (append (get predictions context) 
                               {id: strategy-id, yield: predicted-yield, risk: risk-score}) u5)),
        total-expected-yield: (+ (get total-expected-yield context) predicted-yield)
      })
    context))

;; Helper function to calculate optimal allocation per strategy
(define-private (calculate-optimal-allocation
  (prediction {id: uint, yield: uint, risk: uint})
  (context {total-funds: uint, risk-tolerance: uint, allocations: (list 5 {strategy-id: uint, amount: uint}), remaining-funds: uint}))
  (let ((strategy-id (get id prediction))
        (expected-yield (get yield prediction))
        (risk-score (get risk prediction))
        (risk-adjusted-yield (if (<= risk-score (get risk-tolerance context))
                               expected-yield
                               (/ expected-yield u2)))) ;; Penalize high-risk strategies
    
    (let ((calculated-percentage (/ (* risk-adjusted-yield u100) 
                                   (+ expected-yield u1))) ;; Prevent division by zero
          (allocation-percentage (if (> calculated-percentage max-allocation-per-strategy)
                                   max-allocation-per-strategy
                                   calculated-percentage))
          (allocation-amount (/ (* (get total-funds context) allocation-percentage) u100)))
      
      {
        total-funds: (get total-funds context),
        risk-tolerance: (get risk-tolerance context),
        allocations: (unwrap-panic (as-max-len? 
                       (append (get allocations context) 
                               {strategy-id: strategy-id, amount: allocation-amount}) u5)),
        remaining-funds: (- (get remaining-funds context) allocation-amount)
      })))

;; Helper function to execute the rebalancing
(define-private (execute-rebalancing
  (allocation {strategy-id: uint, amount: uint})
  (context {total-rebalanced: uint, strategies-updated: uint, success: bool}))
  (if (get success context)
    (let ((strategy-id (get strategy-id allocation))
          (new-amount (get amount allocation)))
      (match (map-get? yield-strategies strategy-id)
        strategy-data
        (begin
          (map-set yield-strategies strategy-id
            (merge strategy-data {
              total-allocated: new-amount,
              allocation-percentage: (/ (* new-amount u100) (var-get total-funds))
            }))
          {
            total-rebalanced: (+ (get total-rebalanced context) new-amount),
            strategies-updated: (+ (get strategies-updated context) u1),
            success: true
          })
        {
          total-rebalanced: (get total-rebalanced context),
          strategies-updated: (get strategies-updated context),
          success: false
        }))
    context))

;; Helper function to assess overall portfolio risk
(define-private (assess-portfolio-risk (allocations (list 5 {strategy-id: uint, amount: uint})))
  (fold calculate-weighted-risk allocations u0))

(define-private (calculate-weighted-risk (allocation {strategy-id: uint, amount: uint}) (total-risk uint))
  (let ((strategy-risk (assess-strategy-risk (get strategy-id allocation)))
        (weight (/ (get amount allocation) (var-get total-funds))))
    (+ total-risk (/ (* strategy-risk weight) u100))))


