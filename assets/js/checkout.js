window.Checkout = {}

window.Checkout.init = function(userId, email) {
  Paddle.Setup({vendor: 49430});

  const triggers = document.querySelectorAll('[data-product-id]')

  for (const trigger of triggers) {
    trigger.addEventListener('click', function(e) {
      const plan = e.target.getAttribute('data-product-id')

      Paddle.Checkout.open({
        product: plan,
        email: email,
        passthrough: userId,
        disableLogout: true,
        success: '/settings'
      });

    })
  }
}
