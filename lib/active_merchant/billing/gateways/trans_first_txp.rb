require 'savon'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TransFirstTxpGateway < Gateway
      self.test_url = 'https://ws.cert.processnow.com/portal/merchantframework/MerchantWebServices-v1?wsdl'
      self.live_url = 'https://example.com/live'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'https://www.transfirst.com/'

      # The name of the gateway
      self.display_name = 'TransFirst TXP'

      self.money_format = :cents

      def initialize(options = {})
        requires!(options, :gateway_id, :registration_key)
        super
      end

      def authorize(money, creditcard, options = {})
        commit(build_auth_or_purchase(creditcard, options, money, '0'))
      end

      def purchase(money, creditcard, options = {})
        commit(build_auth_or_purchase(creditcard, options, money, '1'))
      end

      def capture(money, authorization, options = {})
        commit(build_capture(authorization, money))
      end

      def credit(money, authorization, options = {})
        commit(build_credit(authorization, money))
      end

      def void(authorization, options = {})
        commit(build_void(authorization))
      end

      private

      def build
        xml = Builder::XmlMarkup.new
        yield xml
        xml.target!
      end

      def build_merchant
        build do |xml|
          xml.v1(:merc) do
            xml.v1(:id, options[:gateway_id])
            xml.v1(:regKey, options[:registration_key])
            xml.v1(:inType, 1) # Merchant Web Service
          end
        end
      end

      def build_card(creditcard)
        build do |xml|
          xml.v1(:card) do
            xml.v1(:pan, creditcard.number)
            xml.v1(:sec, creditcard.verification_value) if creditcard.verification_value
            xml.v1(:xprDt, "%2d%02d" % [creditcard.year % 100, creditcard.month])
          end
        end
      end

      def build_contact(creditcard, options)
        build do |xml|
          xml.v1(:contact) do
            xml.v1(:fullName, ("%s %s" % [creditcard.first_name, creditcard.last_name])[0...61])
            xml.v1(:phone) do
              xml.v1(:type, 0)
              xml.v1(:nr, options[:billing_address][:phone][0...15])
            end if options[:billing_address][:phone]
            xml.v1(:addrLn1, options[:billing_address][:address1][0...50])
            xml.v1(:addrLn2, options[:billing_address][:address2][0...50])
            xml.v1(:city,    options[:billing_address][:city][0...40])
            xml.v1(:state,   options[:billing_address][:state][0...2])
            xml.v1(:zipCode, options[:billing_address][:zip][0...9])
            xml.v1(:ctry,   options[:billing_address][:country][0...2])
          end
        end
      end

      def build_auth_or_purchase(creditcard, options, money, tran_code)
        build do |xml|
          xml << build_merchant
          xml.v1(:tranCode, tran_code)
          xml << build_card(creditcard)
          xml << build_contact(creditcard, options)
          xml.v1(:reqAmt, "0#{money}")
        end
      end

      def build_capture(authorization, money)
        build do |xml|
          xml << build_merchant
          xml.v1(:tranCode, 3)
          xml.v1(:reqAmt, "0#{money}")
          xml.v1(:origTranData) do
            xml.v1(:tranNr, authorization)
          end
        end
      end

      def build_credit(authorization, money)
        build do |xml|
          xml << build_merchant
          xml.v1(:tranCode, 4)
          xml.v1(:reqAmt, "0#{money}")
          xml.v1(:origTranData) do
            xml.v1(:tranNr, authorization)
          end
        end
      end

      def build_void(authorization)
        build do |xml|
          xml << build_merchant
          xml.v1(:tranCode, 2)
          xml.v1(:origTranData) do
            xml.v1(:tranNr, authorization)
          end
        end
      end

      def parse(body)
        body.to_hash[:send_tran_response]
      end

      def commit(xml_body)
        response = parse(post_data do |xml|
          xml << xml_body
        end)

        ActiveMerchant::Billing::Response.new(response[:rsp_code] == "00", message_from(response), response,
          :test => test?,
          :authorization => (response[:tran_data][:tran_nr] rescue nil),
          :avs_result => { :code => response[:avs_code] },
          :cvv_result => response[:cvv2_code]
        )
      end

      def message_from(response)
        case response[:rsp_code]
        when "00"; "Approved or completed successfully"
        when "01"; "Refer to card issuer"
        when "02"; "Refer to card issuer, special condition"
        when "03"; "Invalid merchant"
        when "04"; "Pick-up card"
        when "05"; "Do not honor"
        when "06"; "Error"
        when "07"; "Pick-up card, special condition"
        when "08"; "Honor with identification"
        when "10"; "Approved, partial"
        when "11"; "VIP Approval"
        when "12"; "Invalid transaction"
        when "13"; "Invalid amount"
        when "14"; "Invalid card number"
        when "15"; "No such issuer"
        when "17"; "Customer cancellation"
        when "19"; "Re-enter transaction"
        when "21"; "No action taken"
        when "25"; "Unable to locate record"
        when "28"; "File update file locked"
        when "30"; "Format error"
        when "32"; "Completed partially" # Valid for MasterCard Reversal Requests Only - Used in a reversal message to indicate the reversal request is for an amount less than the original transaction.
        when "39"; "No credit account"
        when "41"; "Lost card, pick-up"
        when "43"; "Stolen card, pick-up"
        when "51"; "Not sufficient funds"
        when "52"; "No checking account"
        when "53"; "No savings account"
        when "54"; "Expired card"
        when "55"; "Incorrect PIN"
        when "57"; "Transaction not permitted to cardholder"
        when "58"; "Transaction not permitted on terminal"
        when "59"; "Suspected fraud"
        when "61"; "Exceeds withdrawal limit"
        when "62"; "Restricted card"
        when "63"; "Security violation"
        when "65"; "Exceeds withdrawal frequency"
        when "68"; "Response received too late"
        when "69"; "Advice received too late"
        when "70"; "Reserved for future use"
        when "75"; "PIN tries exceeded"
        when "76"; "Reversal: Unable to locate previous message (no match on Retrieval Reference Number)."
        when "77"; "Previous message located for a repeat or reversal, but repeat or reversal data is inconsistent with original message."
        when "78"; "Invalid/non-existent account – Decline (MasterCard specific)"
        when "79"; "Already reversed (by Switch)"
        when "80"; "No financial Impact (Reserved for declined debit)"
        when "81"; "PIN cryptographic error found by the Visa security module during PIN decryption."
        when "82"; "Incorrect CVV"
        when "83"; "Unable to verify PIN"
        when "84"; "Invalid Authorization Life Cycle – Decline (MasterCard) or Duplicate Transaction Detected (Visa)"
        when "85"; "No reason to decline a request for Account Number Verification or Address Verification"
        when "86"; "Cannot verify PIN"
        when "91"; "Issuer or switch inoperative"
        when "92"; "Destination Routing error"
        when "93"; "Violation of law"
        when "94"; "Duplicate Transmission (Integrated Debit and MasterCard)"
        when "96"; "System malfunction"
        when "B1"; "Surcharge amount not permitted on Visa cards or EBT Food Stamps"
        when "B2"; "Surcharge amount not supported by debit network issuer"
        when "N0"; "Force STIP"
        when "N3"; "Cash service not available"
        when "N4"; "Cash request exceeds Issuer limit"
        when "N5"; "Ineligible for re-submission"
        when "N7"; "Decline for CVV2 failure"
        when "N8"; "Transaction amount exceeds preauthorized approval amount"
        when "P0"; "Approved; PVID code is missing, invalid, or has expired"
        when "P1"; "Declined; PVID code is missing, invalid, or has expired"
        when "P2"; "Invalid biller Information"
        when "R0"; "The transaction was declined or returned, because the cardholder requested that payment of a specific recurring or installment payment transaction be stopped."
        when "R1"; "The transaction was declined or returned, because the cardholder requested that payment of all recurring or installment payment transactions for a specific merchant account be stopped."
        when "Q1"; "Card Authentication failed"
        when "XA"; "Forward to Issuer"
        when "XD"; "Forward to Issuer"
        else;      "Unhandled Error Code: #{response[:rsp_code]}"
        end
      end

      def post_data
        begin
          Savon.client(test_url).request("v1", "SendTranRequest") do
            soap.xml do |xml|
              namespaces = {
                "xmlns:env" => "http://schemas.xmlsoap.org/soap/envelope/",
                'xmlns:v1'  => 'http://postilion/realtime/merchantframework/xsd/v1/'
              }
              xml.env(:Envelope, namespaces) do
                xml.env(:Body) do
                  xml.v1(:SendTranRequest) do
                    yield xml
                  end
                end
              end
            end
          end
        rescue Savon::SOAP::Fault => e
          {:send_tran_response => {:rsp_code => e.message}}
        end
      end
    end
  end
end
