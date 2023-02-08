const burger = document.getElementById('hamburgermenu')
const nav = document.getElementById('navlinks')


function toggleMenu() {
nav.classList.toggle('navactive')
burger.classList.toggle('crossedline')
}

burger.addEventListener('click', toggleMenu)