window.Checkout = {}

window.Checkout.init = function(userId, email) {
  Paddle.Setup({vendor: 49430});

  const triggers = document.querySelectorAll('[data-plan-select]')

  for (const trigger of triggers) {
    trigger.addEventListener('click', function(e) {
      const plan = e.target.getAttribute('data-plan-select')

      Paddle.Checkout.open({
        product: 558018,
        email: email,
        passthrough: userId
      });

    })
  }
}
