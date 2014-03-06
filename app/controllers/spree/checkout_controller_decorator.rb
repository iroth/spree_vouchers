module Spree
  CheckoutController.class_eval do
    respond_to :html, :js

    
    def apply_voucher
      Rails.logger.error "applycrap0"

      @order = Order.find params[:voucher_order_id]
      voucher = Voucher.find_by_number params[:voucher_number]

      if voucher
        voucher_payment_method = Spree::PaymentMethod.available.detect { |pm| 
          pm.class == Spree::PaymentMethod::Voucher 
        }
        
        amount = [voucher.authorizable_amount, 
                  @order.outstanding_balance - @order.voucher_total].min

        # we don't actually want to authorize until the order is completed,
        # so do a 'pretend' auth to get the approve/reject as well as the new totals
        if amount > 0 && voucher.soft_authorize(amount, @order.currency)
          @payment = @order.payments.create(source: voucher,
                                         payment_method: voucher_payment_method,
                                         amount: amount)

          @no_more_payment_required = @order.total_minus_pending_vouchers <= 0
            
          flash[:notice] = Spree.t(:voucher_applied_for_amount_with_remaining_balance, 
                                 {
                                   payment_amount: Spree::Money.new(@payment.amount, { currency: @order.currency }),
                                   available: Spree::Money.new((voucher.authorizable_amount - @payment.amount),{ currency: @order.currency })
                                 })
        else
          flash[:error] = Spree.t(:unable_to_apply_voucher_with_remaining_balance, {
                                   available: Spree::Money.new((voucher.authorizable_amount),
                                                               { currency: @order.currency }),
                                   expiration: voucher.expiration || Spree.t('no_voucher_expiration_applicable'),
                                   currency: voucher.currency})
        end
      else
        flash[:error] = Spree.t(:no_voucher_exists_for_number, number: params[:voucher_number])
      end

      respond_with(@order)
    end
  end
end
