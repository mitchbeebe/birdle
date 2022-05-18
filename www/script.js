function getCookies(){
  var res = Cookies.get();
  Shiny.setInputValue('cookies', res);
}

/* Shiny.addCustomMessageHandler('cookie-set', function(msg){
  Cookies.set(msg.name, msg.value);
  getCookies();
})

Shiny.addCustomMessageHandler('cookie-remove', function(msg){
  Cookies.remove(msg.name);
  getCookies();
})
*/

$(document).on('shiny:connected', function(ev){
  if(Cookies.get('user_id') == null) {
    Cookies.set('user_id', Date.now());
  }
  getCookies();
  Shiny.setInputValue("load", 1, {priority: "event"});
})

function collapse_bs() {
  const navLinks = document.querySelectorAll('.nav-item');
  const menuToggle = document.getElementsByClassName('navbar-collapse')[0];
  const bsCollapse = new bootstrap.Collapse(menuToggle, {
    toggle: false
  });
  navLinks.forEach((l) => {
      l.addEventListener('click', () => { bsCollapse.toggle() })
  });
}