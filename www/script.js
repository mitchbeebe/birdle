function getCookies(){
  var res = Cookies.get();
  Shiny.setInputValue('cookies', res);
}

$(document).on('shiny:connected', function(ev){
  if(Cookies.get('user_id') == null) {
    Cookies.set('user_id', Date.now(), { expires: 10000 });
  }
  getCookies();
  Shiny.setInputValue("load", 1, {priority: "event"});
})

var socket_timeout_interval;
var n = 0;

$(document).on('shiny:connected', function(event) {
  socket_timeout_interval = setInterval(function() {
    Shiny.onInputChange('alive_count', n++)
  }, 30000);
});

$(document).on('shiny:disconnected', function(event) {
  clearInterval(socket_timeout_interval)
});

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