class Spree::GestpayConfiguration < Spree::Preferences::Configuration
  preference :login, :string
	preference :password, :string
end