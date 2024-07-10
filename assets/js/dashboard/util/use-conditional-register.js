import {useState, useEffect} from "react";

export function useConditionalRegister({activeCondition, register, deregister}) {
    const [isActive, setIsActive] = useState(false);
    
    useEffect(() => {
      const registerOnce = () => {
        if (!isActive) {
          register()
          setIsActive(true)
        }
      }
  
      const cleanup = () => {
        if (isActive) {
          deregister()
          setIsActive(false)
        }
      }
  
      if (activeCondition) {
        registerOnce();
      } else {
        cleanup();
      }
      
      return cleanup;
    }, [register, deregister, activeCondition, isActive])
  }
  