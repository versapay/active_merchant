require 'test_helper'

class RemoteTransFirstTxpGatewayTest < Test::Unit::TestCase
  def us_address(options = {})
    address(
      {
        :city    => 'New York',
        :state   => 'NY',
        :zip     => '10120',
        :country => 'US'
      }.merge(options)
    )
  end

  def setup
    @gateway = TransFirstTxpGateway.new(fixtures(:trans_first_txp))

    @amount = 100
    @declined_amount = 21 # Will return Not Sufficient Funds
    @credit_card = credit_card('4000100011112224')

    @options = {
      :order_id => '1',
      :billing_address => us_address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved or completed successfully', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Not sufficient funds', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved or completed successfully', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_credit
    puts "Need to wait until Midnight PST for purchases to settle before it can be credited"
    authorization = '000000000000' # Replace me
    return

    assert credit = @gateway.credit(@amount, authorization)
    assert_success credit
  end

  def test_authorize_and_void
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved or completed successfully', auth.message
    assert auth.authorization

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Unhandled Error Code: (S:Server) Validation Failure', response.message
  end

  def test_invalid_login
    gateway = TransFirstTxpGateway.new(
                :gateway_id => 'bad',
                :registration_key => 'bad'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Unhandled Error Code: (S:Server) Service Exception', response.message
  end
end
