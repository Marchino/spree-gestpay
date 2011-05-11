require 'spree_core'
require 'spree_gestpay_hooks'

module SpreeGestpay
  class Engine < Rails::Engine

    config.autoload_paths += %W(#{config.root}/lib)

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.env.production? ? require(c) : load(c)
      end
      
      require 'active_merchant'
      # register of Gestpay Banca Sella BillingIntegration
      BillingIntegration::Gestpay.register
       
      require 'rgestpay/lib/gest_pay'
    end

    config.to_prepare &method(:activate).to_proc
  end
end
