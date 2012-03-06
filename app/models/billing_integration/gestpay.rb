class BillingIntegration::Gestpay < BillingIntegration
	preference :login, :string
	preference :password, :string

  def provider_class
    ActiveMerchant::Billing::Integrations::Gestpay
  end
   
  def source_required?
    false
  end
end