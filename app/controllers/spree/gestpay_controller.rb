# encoding: utf-8
module Spree
  class GestpayController < Spree::BaseController
    include Spree::Core::ControllerHelpers::Order
    helper 'spree/orders', 'spree/store'
    skip_before_filter :verify_authenticity_token, :only => [:comeback, :comeback_s2s]
    
    def show
      if params[:payment_method_id] and PaymentMethod.exists? params[:payment_method_id]
        @payment_method = PaymentMethod.find params[:payment_method_id]
      else
        flash[:error] = "ERRORE, parametro payment_method_id errato, il metodo di pagamento con id=#{params[:payment_method_id]} non esiste !"
        redirect_to checkout_state_url(:payment)
      end
      @shop_login = @payment_method.preferred_login
      @server = @payment_method.preferred_server
      c = GestPay::CryptRequest.new(@shop_login, @server)
      if params[:order_id] and Order.exists? params[:order_id]
        @order = Order.find params[:order_id]
      else
        flash[:error] = "ERRORE, parametro order_id errato, l'ordine id=#{params[:order_id]} non esiste !"
        redirect_to checkout_state_url(:payment)
      end
      t = GestPay::TransactionData.new(
            :amount => @order.total,
            :currency => 242,
            :shop_transaction_id => @order.number
          )
      # Get the first encryption
      t = c.encrypt(t)
      # Check for errors
      unless t[:error_code].nil?
        flash[:error] = "ERROR on first encryption. #{t[:error_code]} / #{t.inspect}"
        redirect_to checkout_state_url(:payment)
      end
      # Dati per il form
      @a = @shop_login
      @b = t[:encrypted_str]
      @form_url = (@server == 'test') ? "https://testecomm.sella.it/gestpay/pagam.asp" : "https://ecomm.sella.it/gestpay/pagam.asp"
      
    end
    
    def comeback
      @a = params[:a]
      @b = params[:b]  
      @server = params[:server]
      @server ||= "live"
      c = GestPay::CryptRequest.new(@a, @server)
      t = c.decrypt(@b)
      @order = Order.find_by_number(t[:shop_transaction_id]) if t[:shop_transaction_id]
      logger.info "***GESTPAY***comeback*** Data in comeback: #{params} #{t} #{@order}"
      if t[:shop_transaction_id] and @order
        @order.payments.valid.last.started_processing!
        case t[:transaction_result]
        when "XX" # Esito transazione sospeso (pagamento tramite bonifico)
          flash[:error] = "Esito transazione sospeso, bonifico. #{t[:transaction_result]}"
          # TODO : andrebbe in realtà accettato come pagamento ma senza conferma dell'avvenuta transazione ?
          redirect_to checkout_state_url(:payment)
        when "OK" # Esito transazione positivo
          @order.state = 'complete'
          @order.finalize!
          session[:order_id] = nil
          redirect_to order_url(@order, {:checkout_complete => true, :order_token => @order.token}), :notice => I18n.t("gestpay_payment_success")
        when "KO" # Esito transazione negativo
          flash[:error] = "Esito transazione negativo: #{t[:transaction_result]}"
          redirect_to checkout_state_url(:payment)
        else # Esito transazione indefinito
          flash[:error] = "Esito transazione indefinito (annullato) #{t[:transaction_result]}"
          redirect_to checkout_state_url(:payment)
        end 
      else
        flash[:error] = "C'è stato un errore nella ricezione dei parametri dal server Gestpay per cui non è possibile stabilire l'esito della transazione. Vi preghiamo di contattare il venditore per verificare lo stato del pagamento e confermare manualmente l'ordine."
        redirect_to checkout_state_url(:payment)
      end
    end
    
    # comeback server to server: conferma di pagamento
    def comeback_s2s
      @a = params[:a]
      @b = params[:b]
      @server = params[:server]
      @server ||= "live"
      c = GestPay::CryptRequest.new(@a, @server)
      t = c.decrypt(@b)
      logger.info "***GESTPAY***S2S*** Data in comeback_s2s: #{params} #{t} #{@order}"
      if t[:shop_transaction_id] and Order.find_by_number t[:shop_transaction_id]  
        logger.info "***GESTPAY***S2S*** comeback_s2s: #{t.inspect}"
        @order = Order.find_by_number t[:shop_transaction_id]  
        logger.info "***GESTPAY***S2S*** comeback_s2s: #{@order.inspect} #{@order.payments.valid.last.inspect}"
        @order.payments.valid.last.started_processing
        logger.info "***GESTPAY***S2S*** comeback_s2s: #{@order.payments.valid.last.inspect}"
        case t[:transaction_result]
          when "XX" # Esito transazione sospeso (pagamento tramite bonifico)
            @order.payments.valid.last.pend
          when "OK" # Esito transazione positivo
            @order.payments.valid.last.complete
          when "KO" # Esito transazione negativo
            @order.payments.valid.last.fail
          else # Esito transazione indefinito
            logger.info "***GESTPAY***S2S*** Esito transazione indefinito - comeback_s2s: #{params} #{t} #{@order}"
        end      
        logger.info "***GESTPAY***S2S*** comeback_s2s: #{@order.payments.valid.last.inspect}"
      else
        raise "ERRORE, parametro ':shop_transaction_id' errato o assente, l'ordine number=#{t[:shop_transaction_id]} non esiste !"
      end
    end
    
  end
end

