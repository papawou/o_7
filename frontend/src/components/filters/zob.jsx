import React from 'react'

import _langs from '../../data/langs'
import _socials from '../../data/socials'
import _mentalities from '../../data/mentalities'
import _platforms from '../../data/platforms'

export const Langs = ({ lang, disabled = false, handleChange }) =>
    <select disabled={disabled} onChange={handleChange} name="lang" value={lang}>
        <option value="" disabled={true}>** select a lang **</option>
        {
            _langs.map(lang =>
                <option key={lang} value={lang}>{lang}</option>
            )
        }
    </select>

export const Mentalities = ({ mentality, handleChange }) =>
    <select onChange={handleChange} name="mentality" value={mentality}>
        <option value="">-- select a mentality --</option>
        {
            _mentalities.map(mentality =>
                <option key={mentality} value={mentality}>{mentality}</option>
            )
        }
    </select>

export const Social = ({ id, mic, sound, handleChange }) =>
    <React.Fragment>
        <select onChange={handleChange} name="id" value={id}>
            <option value="none">-- select a social --</option>
            {
                _socials.map(social =>
                    <option key={social} value={social}>{social}</option>
                )
            }
        </select>
        <label>SOUND ? <input onChange={handleChange} disabled={id == "none"} type="checkbox" name="sound" checked={sound} /></label>
        <label>MIC ? <input onChange={handleChange} disabled={id == "none"} type="checkbox" name="mic" checked={mic} /></label>
    </React.Fragment>

//GAMES
export const Platforms = ({ platforms = null, platform, handleChange }) =>
    <select onChange={handleChange} name="platform" value={platform}>
        <option disabled={true} value="">** select a platform **</option>
        {
            platforms ?
                platforms.map(platform => <option key={platform} value={platform}>{platform}</option>) :
                _platforms.map(platform => <option key={platform} value={platform}>{platform}</option>)
        }
    </select>

export const Games = ({ id_game, handleChange }) =>
    <select name="id_game" value={id_game} onChange={handleChange}>
        <option disabled={true} value="">** select a game **</option>
        <option value="overwatch">Overwatch</option>
        <option value="squad">Squad</option>
    </select>