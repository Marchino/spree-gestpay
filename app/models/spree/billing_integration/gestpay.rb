class Spree::BillingIntegration::Gestpay < Spree::BillingIntegration
	preference :login, :string
	preference :password, :string
	
	attr_accessible :preferred_login, :preferred_password, :preferred_server, :preferred_test_mode

  def provider_class
    ActiveMerchant::Billing::Integrations::Gestpay
  end
 
  def source_required?
    false
  end
end