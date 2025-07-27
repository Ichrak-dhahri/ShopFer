*** Settings ***
Documentation    Tests automatisés basiques pour application e-commerce Angular
Library          SeleniumLibrary    timeout=10s    implicit_wait=2s
Library          Collections
Library          String
Library          DateTime
Test Setup       Open Browser Setup
Test Teardown    Close Browser And Capture On Failure
Suite Setup      Log    Suite de tests e-commerce démarrée
Suite Teardown   Log    Suite de tests e-commerce terminée

*** Variables ***
${BASE_URL}           http://localhost:4200
${BROWSER}            headlesschrome
${TIMEOUT}            15s

# Routes de l'application
${HOME_ROUTE}         /home
${LOGIN_ROUTE}        /login
${SIGNUP_ROUTE}       /sign-up

# Selectors basiques
${BODY_SELECTOR}      css:body
${APP_ROOT}           css:app-root

*** Keywords ***
Open Browser Setup
    [Documentation]    Configure et ouvre le navigateur
    Set Selenium Speed    0.5s
    Open Browser    ${BASE_URL}    ${BROWSER}
    Maximize Browser Window
    Set Selenium Timeout    ${TIMEOUT}
    Wait Until Page Contains Element    ${BODY_SELECTOR}    timeout=${TIMEOUT}
    Log    Browser opened successfully

Close Browser And Capture On Failure
    [Documentation]    Ferme le navigateur et capture les informations en cas d'échec
    Run Keyword If Test Failed    Capture Page Screenshot    failure-${TEST_NAME}-{index}.png
    Run Keyword If Test Failed    Log Source
    Run Keyword If Test Failed    Log Location
    Close Browser

Wait For Page Load
    [Documentation]    Attend que la page soit complètement chargée
    Wait Until Page Contains Element    ${BODY_SELECTOR}    timeout=${TIMEOUT}
    Sleep    2s

Navigate To URL
    [Arguments]    ${url}
    [Documentation]    Navigue vers une URL et attend le chargement
    Go To    ${url}
    Wait For Page Load

Check Page Contains Text
    [Arguments]    ${text}
    [Documentation]    Vérifie que la page contient un texte spécifique
    Wait Until Page Contains    ${text}    timeout=${TIMEOUT}

*** Test Cases ***
TC001 - Vérifier l'accès à l'application
    [Documentation]    Test de base pour vérifier que l'application est accessible
    [Tags]    smoke    basic
    Navigate To URL    ${BASE_URL}
    Page Should Contain Element    ${APP_ROOT}
    Log    Application accessible

TC002 - Vérifier la page d'accueil
    [Documentation]    Vérifier que la page d'accueil se charge
    [Tags]    smoke    ui
    Navigate To URL    ${BASE_URL}${HOME_ROUTE}
    Wait For Page Load
    ${title}=    Get Title
    Log    Page title: ${title}
    Location Should Contain    ${HOME_ROUTE}

TC003 - Navigation vers la page de connexion
    [Documentation]    Vérifier la navigation vers la page de connexion
    [Tags]    navigation    ui
    Navigate To URL    ${BASE_URL}${LOGIN_ROUTE}
    Wait For Page Load
    Location Should Contain    ${LOGIN_ROUTE}
    Log    Login page accessible

TC004 - Navigation vers la page d'inscription
    [Documentation]    Vérifier la navigation vers la page d'inscription
    [Tags]    navigation    ui
    Navigate To URL    ${BASE_URL}${SIGNUP_ROUTE}
    Wait For Page Load
    Location Should Contain    ${SIGNUP_ROUTE}
    Log    Signup page accessible

TC005 - Vérifier les éléments de base de la page
    [Documentation]    Vérifier que les éléments de base sont présents
    [Tags]    ui    elements
    Navigate To URL    ${BASE_URL}
    Wait For Page Load
    
    # Vérifier la présence d'éléments HTML de base
    Page Should Contain Element    css:html
    Page Should Contain Element    css:head
    Page Should Contain Element    css:body
    Page Should Contain Element    ${APP_ROOT}
    
    Log    Basic page elements found

TC006 - Test de performance simple
    [Documentation]    Test basique de temps de chargement
    [Tags]    performance
    ${start_time}=    Get Current Date    result_format=epoch
    Navigate To URL    ${BASE_URL}
    ${end_time}=    Get Current Date    result_format=epoch
    ${load_time}=    Evaluate    ${end_time} - ${start_time}
    
    Log    Page load time: ${load_time} seconds
    Should Be True    ${load_time} < 10    Page should load in less than 10 seconds

TC007 - Vérifier le responsive design
    [Documentation]    Test basique de responsive design
    [Tags]    responsive    ui
    Navigate To URL    ${BASE_URL}
    
    # Test avec différentes tailles d'écran
    Set Window Size    1920    1080
    Wait For Page Load
    Capture Page Screenshot    desktop-view.png
    
    Set Window Size    768    1024
    Wait For Page Load
    Capture Page Screenshot    tablet-view.png
    
    Set Window Size    375    667
    Wait For Page Load
    Capture Page Screenshot    mobile-view.png
    
    Log    Responsive design test completed

TC008 - Test de navigation de base
    [Documentation]    Test de navigation entre les pages principales
    [Tags]    navigation    workflow
    
    # Page d'accueil
    Navigate To URL    ${BASE_URL}${HOME_ROUTE}
    Wait For Page Load
    
    # Page de connexion
    Navigate To URL    ${BASE_URL}${LOGIN_ROUTE}
    Wait For Page Load
    
    # Page d'inscription
    Navigate To URL    ${BASE_URL}${SIGNUP_ROUTE}
    Wait For Page Load
    
    # Retour à l'accueil
    Navigate To URL    ${BASE_URL}${HOME_ROUTE}
    Wait For Page Load
    
    Log    Basic navigation test completed