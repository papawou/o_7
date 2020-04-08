//CSS
import styled from 'styled-components'
export const Container = styled.div`
	grid-area:content;

	display: flex;
	flex-flow: row wrap;
`

export const Category = styled.div`
	flex: 1 1 100%;

	display:flex;
	align-items:stretch;
	border: 1px solid;
`

export const Option = styled.div`
	flex: 1 1 50%;

	display:flex;
	flex-direction: column;
	justify-content: center;
	align-items:center;

	border: 1px dashed;
`
