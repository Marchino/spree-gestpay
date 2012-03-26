Rails.application.routes.draw do
  # Add your extension routes here
  match '/gestpay/show/:order_id/:payment_method_id' => 'gestpay#show', :as => :gestpay_show
  match '/gestpay/comeback(/:server)' => 'gestpay#comeback', :as => :gestpay_comeback
  match '/gestpay/comeback_s2s(/:server)' => 'gestpay#comeback_s2s', :as => :gestpay_comeback_s2s
end
