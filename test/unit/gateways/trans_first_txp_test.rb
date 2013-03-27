require 'test_helper'

class TransFirstTxpGatewayTest < Test::Unit::TestCase
  def setup
    @gateway = TransFirstTxpGateway.new(fixtures(:trans_first_txp))

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:post_data).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '000000740641', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:post_data).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_error_request
    @gateway.expects(:post_data).returns(error_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    {
      :send_tran_response => {
        :rsp_code=>"00",
        :@xmlns=>"http://postilion/realtime/portal/soa/xsd/Faults/2009/01",
        :tran_data=>{
          :swch_key=>"0A10092D13BBAAEE27BCC70CEBF801",
          :dt_tm=>DateTime.new(2012, 12, 20, 15, 38, 41),
          :amt=>"000000000100",
          :auth=>"Lexc05",
          :stan=>"000941",
          :tran_nr=>"000000740641"
        },
        :"@xmlns:ns2"=>"http://postilion/realtime/merchantframework/xsd/v1/",
        :auth_rsp=>{:aci=>"Y"},
        :map_caid=>"300979940268000",
        :card_type=>"0"
      }
    }
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    {
      :send_tran_response => {
        :rsp_code=>"51",
        :@xmlns=>"http://postilion/realtime/portal/soa/xsd/Faults/2009/01",
        :tran_data=>{
          :swch_key=>"0A10092D13BBAAEE6AFCC31BB3CE51",
          :dt_tm=>DateTime.new(2012, 12, 20, 15, 38, 41),
          :amt=>"000000000021",
          :auth=>"Lexc05",
          :stan=>"000942",
          :tran_nr=>"000000740651"
        },
        :"@xmlns:ns2"=>"http://postilion/realtime/merchantframework/xsd/v1/",
        :auth_rsp=>{:aci=>"Y"},
        :map_caid=>"300979940268000",
        :card_type=>"0"
      }
    }
  end

  def successful_auth_response
    {
      :send_tran_response => {
        :rsp_code=>"00",
        :@xmlns=>"http://postilion/realtime/portal/soa/xsd/Faults/2009/01",
        :"@xmlns:ns2"=>"http://postilion/realtime/merchantframework/xsd/v1/",
        :auth_rsp=>{:aci=>"Y"},
        :tran_data=>{
          :dt_tm=>DateTime.new(2012, 12, 20, 15, 38, 41),
          :amt=>"000000000100",
          :auth=>"Lexc05",
          :stan=>"000950",
          :tran_nr=>"000000740731",
          :swch_key=>"0A10092D13BBAC2900A076F034841A"},
        :map_caid=>"300979940268000",
        :card_type=>"0"
      }
    }
  end

  def successful_capture_response
    {
      :send_tran_response => {
        :rsp_code=>"00",
        :@xmlns=>"http://postilion/realtime/portal/soa/xsd/Faults/2009/01",
        :"@xmlns:ns2"=>"http://postilion/realtime/merchantframework/xsd/v1/",
        :auth_rsp=>nil,
        :tran_data=>{
          :dt_tm=>DateTime.new(2012, 12, 20, 15, 38, 41),
          :amt=>"000000000100",
          :auth=>"Lexc05",
          :stan=>"000951",
          :tran_nr=>"000000740731",
          :swch_key=>"0A10092D13BBAC2949CAAF9B80E900"
        },
        :map_caid=>"300979940268000",
        :additional_amount=>{
          :currency_code=>"840",
          :amount_sign=>"D",
          :account_type=>"30",
          :amount_type=>"53",
          :amount=>"000000000100"},
        :card_type=>"0"
      }
    }
  end

  def successful_void_response
    {
      :send_tran_response => {
        :card_type=>"0",
        :rsp_code=>"00",
        :@xmlns=>"http://postilion/realtime/portal/soa/xsd/Faults/2009/01",
        :"@xmlns:ns2"=>"http://postilion/realtime/merchantframework/xsd/v1/",
        :auth_rsp=>nil,
        :tran_data=>{
          :dt_tm=>DateTime.new(2012, 12, 20, 15, 38, 41),
          :amt=>"000000000100",
          :auth=>"Lexc05",
          :stan=>"000957",
          :tran_nr=>"000000740791",
          :swch_key=>"0A10092D13BBAC70B59C7E1F9AAA5B"
        },
        :map_caid=>"300979940268000",
        :additional_amount=>{
          :currency_code=>"840",
          :amount_sign=>"D",
          :account_type=>"30",
          :amount_type=>"53",
          :amount=>"000000000100"
        }
      }
    }
  end

  def successful_credit_response
    {
      :send_tran_response => {
        :rsp_code=>"00",
        :@xmlns=>"http://postilion/realtime/portal/soa/xsd/Faults/2009/01",
        :"@xmlns:ns2"=>"http://postilion/realtime/merchantframework/xsd/v1/",
        :auth_rsp=>nil,
        :tran_data=>{
          :dt_tm=>DateTime.new(2012, 12, 20, 15, 38, 41),
          :amt=>"000000000100",
          :stan=>"002038",
          :tran_nr=>"000000667151",
          :swch_key=>"0A10092D13B9B391CC2DBEE1234E61"},
        :map_caid=>"300979940268000",
        :card_type=>"0"
      }
    }
  end

  def error_response
    {
      :send_tran_response => {:rsp_code=>"(S:Server) Validation Failure"}
    }
  end
end
