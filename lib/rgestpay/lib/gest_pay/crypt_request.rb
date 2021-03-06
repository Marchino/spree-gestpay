# This file is part of RGestPay.
#
# RGestPay is a Ruby implementation of GestPayCryptHS the Java
# class for GestPay payments.
#
# RGestPay Copyright (C)2006 by Giovanni Intini <medlar@medlar.it>
# 
# RGestPay is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# RGestPay is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with RGestPay; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# Author: Giovanni Intini <medlar@medlar.it>

module GestPay
  class CryptRequest
    attr_accessor :shop_login, :server

    DOMAIN_NAME = "ecomm.sella.it"
    DOMAIN_NAME_TEST = "testecomm.sella.it"
    VERSION = "2.0"
    ENCRYPT_URL = "/CryptHTTPS/Encrypt.asp"
    DECRYPT_URL = "/CryptHTTPS/Decrypt.asp"

    def initialize(shop_login, server)
      @shop_login = shop_login
      @server = server
    end

    def encrypt(transaction_data)
      if @shop_login != "" && transaction_data.ready_to_encrypt?
        begin
          response = post_ssl(encrypt_url(transaction_data))
          TransactionData.new(parse_encryption_response(response.body)) if response.body
        rescue Exception => e      
          TransactionData.new :error_code => 9999, :error_description => "Connection Error (#{e.message})"          
        end
      elsif @shop_login.size == 0
        TransactionData.new :error_code => 546, :error_description => "shop_login not valid"
      else
        TransactionData.new transaction_data.encrypt_error
      end
    end

    def decrypt(string)
      unless @shop_login.size == 0 || string.size == 0
        begin
          response = post_ssl(decrypt_url(string))
          TransactionData.new(parse_decryption_response(response.body)) if response.body
        rescue Exception => e           
          TransactionData.new :error_code => 9999, :error_description => "Connection Error (#{e.message})"          
        end
      else
        if @shop_login.size == 0
          TransactionData.new :error_code => 546, :error_description => "shop_login not valid"
        else
          TransactionData.new :error_code => 1009, :error_description => "String to Decrypt not valid"
        end
      end
    end

    private
    def encrypt_url(data)
      ENCRYPT_URL + crypt_url(data)
    end

    def decrypt_url(string)
      DECRYPT_URL + crypt_url(string)
    end

    def crypt_url(b)
      "?a=" + CGI.escape(@shop_login) + "&b=" + b.to_str + "&c=" + CGI.escape(VERSION)
    end

    def parse_encryption_response(response_body)
      if response_body =~ %r{#cryptstring#(.*)#/cryptstring#}
        {:encrypted_str => $1}
      else 
        parse_errors(response_body)
      end
    end

    def parse_decryption_response(response_body)
      if response_body =~ %r{#decryptstring#(.*)#/decryptstring#}
        $1
      else 
        parse_errors(response_body)
      end
    end

    def post_ssl(url)
      domain = @server == 'test' ? DOMAIN_NAME_TEST : DOMAIN_NAME
      site = Net::HTTP.new(domain, 443)
      site.use_ssl = true            
      # BEGIN patch for openssl 1.0.1
      site.verify_mode = OpenSSL::SSL::VERIFY_NONE
      # openssl 1.0.1 tends to produce long headers which gc doesnt handle
      # reduce set of ciphers to the one that's known to work with 1.0.0h
      # http://gursevkalra.blogspot.de/2009/09/ruby-and-openssl-based-ssl-cipher.html
      site.ciphers = 'RC4-SHA'
      # force ssl context to TLSv1/SSLv3
      # http://www.ruby-forum.com/topic/200072
      site.instance_eval { @ssl_context = OpenSSL::SSL::SSLContext.new(:TLSv1) } 
      # END patch for openssl 1.0.1           
      site.get2(url)
    end

    def parse_errors(response_body)
      if response_body =~  %r{#error#(.*)#/error#}
        errors = $1.split("-")
        {:error_code => errors[0].to_i, :error_description => errors[1]}
      else
        {:error_code => 9999, :error_description => "No Response from Server"}
      end
    end
  end  
end
