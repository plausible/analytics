import Alpine from 'alpinejs'
import dropdown from "./liveview/dropdown"

// If your components require any hooks or custom uploaders, or if your pages
// require connect parameters, uncomment the following lines and declare them as
// such:
//
// import * as Hooks from "./hooks";
// import * as Params from "./params";
// import * as Uploaders from "./uploaders";

// (function () {
//   window.storybook = { Hooks, Params, Uploaders };
// })();


 // If your components require alpinejs, you'll need to start
 // alpine after the DOM is loaded and pass in an onBeforeElUpdated

Alpine.data('dropdown', dropdown)

 window.Alpine = Alpine
 document.addEventListener('DOMContentLoaded', () => {
   window.Alpine.start();
 });

 (function () {
   window.storybook = {
     LiveSocketOptions: {
       dom: {
         onBeforeElUpdated(from, to) {
           if (from._x_dataStack) {
             window.Alpine.clone(from, to)
           }
         }
       }
     }
   };
 })();
