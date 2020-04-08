import React from 'react'
import { BrowserRouter } from 'react-router-dom'
//COMPONENTS
import Header from './components/header/Header'
import { UserProvider } from './contexts/Auth'
import { LobbyProvider } from './contexts/Lobby'
import Body from './components/body/Body'
import LeftNav from './components/navs/LeftNav'
import RightNav from './components/navs/RightNav'
import LobbyFooter from './components/lobbys/LobbyFooter'
//HOT LOADER
import { hot, setConfig } from 'react-hot-loader'
setConfig({ logLevel: 'debug' })
//CSS
import styledNormalize from 'styled-normalize'
import { createGlobalStyle } from 'styled-components'

const GlobalStyle = createGlobalStyle`
  ${styledNormalize}
  @import url('https://fonts.googleapis.com/css?family=Roboto:300,400,500');
  * {
    font-family: Roboto, sans-serif;
    box-sizing: border-box;
  }

  html,body {
    margin:0;
    padding:0;
  }

  html {
    background-color:grey;
    height:100%;
  }

  body {
    height:100%;
    min-width:100%;
    display:inline-block;
    background-color: purple;
  }

  #root {
    
    background-color: #DCEDC8;
    min-width:100%;
    min-height:100%;

    display: grid;
    grid-template:
      "head" auto
      "content" 1fr
      "foot" auto / 1fr;
}`

const App = () => {
    return <React.Fragment>
        <GlobalStyle />
            <UserProvider>
                <LobbyProvider>
                    <BrowserRouter>
                        <React.Fragment>
                            <Header />
                            <LeftNav />
                            <Body />
                            <RightNav />
                            <LobbyFooter />
                        </React.Fragment>
                    </BrowserRouter>
                </LobbyProvider>
            </UserProvider>
    </React.Fragment >
}

export default hot(module)(App);