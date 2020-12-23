// https://github.com/sealninja/react-grid-system/blob/master/src/utils.js

import { useState, useEffect } from 'react';

const configuration = {
  breakpoints: [640, 768, 1024, 1280, 1536],
  defaultScreenClass: '2xl',
  maxScreenClass: '2xl',
};

const screenClasses = ['sm', 'md', 'lg', 'xl', '2xl'];

export const useScreenClass = (fallbackScreenClass='md') => {
  const getScreenClass = () => {
    const { breakpoints, defaultScreenClass, maxScreenClass } = configuration;

    let newScreenClass = defaultScreenClass;

    const viewport = window.innerWidth;
    if (viewport) {
      newScreenClass = 'sm';
      if (breakpoints[0] && viewport >= breakpoints[0]) newScreenClass = 'md';
      if (breakpoints[1] && viewport >= breakpoints[1]) newScreenClass = 'lg';
      if (breakpoints[2] && viewport >= breakpoints[2]) newScreenClass = 'xl';
      if (breakpoints[3] && viewport >= breakpoints[3]) newScreenClass = '2xl';
    } else if (fallbackScreenClass) {
      newScreenClass = fallbackScreenClass;
    }

    const newScreenClassIndex = screenClasses.indexOf(newScreenClass);
    const maxScreenClassIndex = screenClasses.indexOf(maxScreenClass);
    if (maxScreenClassIndex >= 0 && newScreenClassIndex > maxScreenClassIndex) {
      newScreenClass = screenClasses[maxScreenClassIndex];
    }

    return newScreenClass;
  };

  const [screenClass, setScreenClass] = useState(getScreenClass());


  useEffect(() => {
    const handleWindowResized = () => setScreenClass(getScreenClass());

    window.addEventListener('resize', handleWindowResized, false);

    return () => {
      window.removeEventListener('resize', handleWindowResized, false);
    };
  }, []);

  return screenClass;
};
