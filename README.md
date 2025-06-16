# Cross-chain rebase toke

1. A protocolthat allows users to deposit into a vault and in return recieve rebase tokens
that represent their underlying balance
2. Rebase token- balanceOf function is dynamic to show the changing balance in time.
  - Balance increases linearly in time
  - mint tokens to our users every time they perform an action (minting,burning,transfering or  bridging)
3. Interest rate 
   -Individually set an interest rate for each user based on some global interest rate of the protocol at the time the user deposits into the vault
   -This global interest ratecan only decrease to incentivise/reward early adopters.
   - This will increase the token adoption
