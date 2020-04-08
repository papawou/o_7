//CSS
import styled from 'styled-components'

export const Container = styled.div`
    background:yellow;
    grid-area: content;
`

export const User = styled.div`
    background: red;
    padding: 10px;
    display:flex;
    flex-direction: row;
`

export const Img = styled.img`
    min-width: 100px;
    max-width: 200px;
    
    align-self:center;
    flex: 0 1 100%;
`

export const IconSvg = styled.img`
    width:30px;
`

export const User_Infos = styled.div`
    padding-left: 10px;
    padding-right: 10px;

    align-self:stretch;

    flex: 1 1 auto;

    display:grid;
    grid-template: auto 1fr / 1fr;
    flex-direction:column;
`

export const Names = styled.div`
    padding:10px;
    font-size: 20px;
`
export const Desc = styled.div`
    align-self:center;
    padding: 0 0 10px 0;
`

export const User_topActions = styled.div`
    white-space:nowrap;
    align-self:flex-start;
`

export const Menu = styled.div`
    border: 1px solid black;
    display:flex;
    align-items:center;
    justify-content:space-between;
`
