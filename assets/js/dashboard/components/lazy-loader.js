import React, { useEffect, useState } from 'react'
import { useInView } from 'react-intersection-observer'

export default function LazyLoader(props) {
  const [hasBecomeVisibleYet, setHasBecomeVisibleYet] = useState(false)
  const { ref, inView } = useInView({
    threshold: 0,
  })

  useEffect(() => {
    if (inView && !hasBecomeVisibleYet) {
      setHasBecomeVisibleYet(true)
      props.onVisible && props.onVisible()
    }
  }, [inView])

  return (
    <div ref={ref}>
      {props.children}
    </div>
  )
}
