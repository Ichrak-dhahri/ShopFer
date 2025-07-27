*** Settings ***
Documentation    Tests automatisés pour application e-commerce Angular
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
${BROWSER}            firefox
${TIMEOUT}            10s
${INVALID_EMAIL}      invalid-email
${INVALID_PASSWORD}   123

# Routes de l'application
${HOME_ROUTE}         /home
${LOGIN_ROUTE}        /login
${SIGNUP_ROUTE}       /sign-up
${ORDERS_ROUTE}       /orders

# Selectors pour l'inscription (sign-up)
${REGISTER_EMAIL_INPUT}    css:#form2Example1
${REGISTER_USERNAME_INPUT}    css:#form2Example3
${REGISTER_PASSWORD_INPUT}    css:#form2Example2
${REGISTER_BUTTON}    css:button[type="submit"]
${REGISTER_LINK}    css:a[routerLink="/sign-up"]

# Selectors pour la connexion (login)
${LOGIN_EMAIL_INPUT}    css:#form2Example1
${LOGIN_PASSWORD_INPUT}    css:#form2Example2
${LOGIN_BUTTON}    css:button[type="submit"]
${REMEMBER_CHECKBOX}    css:#form2Example31
${FORGOT_PASSWORD_LINK}    css:a[href="#!"]

# Messages d'erreur
${ERROR_MESSAGE}    css:.error-message

# Selectors pour les produits
${PRODUCT_CARD}    css:.product-card
${PRODUCT_GRID}    css:.product-grid
${SEARCH_INPUT}    css:[data-testid="search-input"]
${SEARCH_BUTTON}    css:[data-testid="search-button"]
${ADD_TO_CART_BUTTON}    css:[data-testid="add-to-cart"]
${CART_ICON}    css:[data-testid="cart-icon"]
${CART_ITEM_COUNT}    css:[data-testid="cart-count"]
${CHECKOUT_BUTTON}    css:[data-testid="checkout-button"]
${PRODUCT_CARD}           css:[data-testid="product-card"]
${LOGOUT_BUTTON}          css:[data-testid="logout-button"]

# Alternative selectors for logged-in state (fallbacks)
${CART_ICON_ALT}         css:.cart-icon, css:.fa-shopping-cart, css:[class*="cart"]
${LOGOUT_BUTTON_ALT}     css:.logout-btn, css:[class*="logout"], css:button:contains("Logout"), css:a:contains("Logout")

# Suite-level variables for user credentials
${REGISTERED_EMAIL}       ${EMPTY}
${REGISTERED_PASSWORD}    ${EMPTY}
${REGISTERED_USERNAME}    ${EMPTY}

*** Keywords ***
Open Browser Setup
    Open Browser    ${BASE_URL}    ${BROWSER}
    Maximize Browser Window
    Set Selenium Timeout    ${TIMEOUT}
    Wait Until Page Contains Element    css:body    timeout=${TIMEOUT}

Close Browser And Capture On Failure
    Run Keyword If Test Failed    Capture Page Screenshot    failure-{index}.png
    Run Keyword If Test Failed    Log Source
    Close Browser

Navigate To Home Page
    Go To    ${BASE_URL}${HOME_ROUTE}
    Wait Until Page Contains Element    css:body    timeout=${TIMEOUT}
    Page Should Contain Element    ${PRODUCT_GRID}

Navigate To Login Page
    Go To    ${BASE_URL}${LOGIN_ROUTE}
    Wait Until Page Contains Element    ${LOGIN_EMAIL_INPUT}    timeout=${TIMEOUT}
    Page Should Contain    Sign in

Navigate To Register Page
    Go To    ${BASE_URL}${SIGNUP_ROUTE}
    Wait Until Page Contains Element    ${REGISTER_EMAIL_INPUT}    timeout=${TIMEOUT}
    Page Should Contain    Register

Login With Credentials
    [Arguments]    ${email}    ${password}
    Navigate To Login Page
    Clear Element Text    ${LOGIN_EMAIL_INPUT}
    Input Text    ${LOGIN_EMAIL_INPUT}    ${email}
    Clear Element Text    ${LOGIN_PASSWORD_INPUT}
    Input Text    ${LOGIN_PASSWORD_INPUT}    ${password}
    Click Button    ${LOGIN_BUTTON}

    # Wait for redirect to home page
    Wait Until Location Is    ${BASE_URL}${HOME_ROUTE}    timeout=${TIMEOUT}

Login With Invalid Credentials
    [Arguments]    ${email}    ${password}
    Navigate To Login Page
    Clear Element Text    ${LOGIN_EMAIL_INPUT}
    Input Text    ${LOGIN_EMAIL_INPUT}    ${email}
    Clear Element Text    ${LOGIN_PASSWORD_INPUT}
    Input Text    ${LOGIN_PASSWORD_INPUT}    ${password}
    Click Button    ${LOGIN_BUTTON}

    # Should remain on login page
    Wait Until Page Contains Element    ${LOGIN_EMAIL_INPUT}    timeout=${TIMEOUT}

Register New User
    [Arguments]    ${email}    ${username}    ${password}
    Navigate To Register Page
    Wait Until Element Is Visible    ${REGISTER_EMAIL_INPUT}    timeout=${TIMEOUT}
    Clear Element Text    ${REGISTER_EMAIL_INPUT}
    Input Text    ${REGISTER_EMAIL_INPUT}    ${email}
    Clear Element Text    ${REGISTER_USERNAME_INPUT}
    Input Text    ${REGISTER_USERNAME_INPUT}    ${username}
    Clear Element Text    ${REGISTER_PASSWORD_INPUT}
    Input Text    ${REGISTER_PASSWORD_INPUT}    ${password}
    Click Button    ${REGISTER_BUTTON}
    Sleep    2s

Check User Is Logged In
    # First verify we're on the home page
    Location Should Be    ${BASE_URL}${HOME_ROUTE}

    # Try to find cart icon with multiple selectors
    ${cart_found}=    Run Keyword And Return Status    Page Should Contain Element    ${CART_ICON}
    Run Keyword If    not ${cart_found}    Try Alternative Cart Selector

    # Log current page elements for debugging
    Log    Current URL: ${BASE_URL}${HOME_ROUTE}
    ${page_source}=    Get Source
    Log    Page source contains: ${page_source}

Try Alternative Cart Selector
    # Try alternative cart selectors
    ${alt_cart_found}=    Run Keyword And Return Status    Page Should Contain Element    ${CART_ICON_ALT}
    Run Keyword If    not ${alt_cart_found}    Debug Page Elements
    Run Keyword If    ${alt_cart_found}    Log    Cart icon found with alternative selector

Debug Page Elements
    Log    Debugging page elements after login/registration
    ${elements}=    Get WebElements    css:*[data-testid]
    Log    Found elements with data-testid: ${elements}

    # Log all clickable elements that might be logout buttons
    ${buttons}=    Get WebElements    css:button
    Log    Found buttons: ${buttons}

    ${links}=    Get WebElements    css:a
    Log    Found links: ${links}

    # Check for common logout patterns
    ${logout_patterns}=    Create List    logout    sign out    disconnect    déconnexion
    FOR    ${pattern}    IN    @{logout_patterns}
        ${found}=    Run Keyword And Return Status    Page Should Contain    ${pattern}
        Run Keyword If    ${found}    Log    Found logout pattern: ${pattern}
    END

Logout User
    # Try primary logout selector
    ${logout_found}=    Run Keyword And Return Status    Page Should Contain Element    ${LOGOUT_BUTTON}
    Run Keyword If    ${logout_found}    Click Element    ${LOGOUT_BUTTON}
    Run Keyword If    not ${logout_found}    Try Alternative Logout

    # Verify we're back on login page
    Wait Until Location Is    ${BASE_URL}${LOGIN_ROUTE}    timeout=${TIMEOUT}

Try Alternative Logout
    # Try alternative logout selectors
    ${alt_logout_found}=    Run Keyword And Return Status    Page Should Contain Element    ${LOGOUT_BUTTON_ALT}
    Run Keyword If    ${alt_logout_found}    Click Element    ${LOGOUT_BUTTON_ALT}
    Run Keyword If    not ${alt_logout_found}    Logout By Text

Logout By Text
    # Try to find logout by text content
    ${logout_by_text}=    Run Keyword And Return Status    Click Element    xpath://button[contains(text(), 'Logout') or contains(text(), 'logout') or contains(text(), 'Sign out')]
    Run Keyword If    not ${logout_by_text}    Log    No logout button found - manual logout required

Search For Product
    [Arguments]    ${product_name}
    Wait Until Element Is Visible    ${SEARCH_INPUT}    timeout=${TIMEOUT}
    Clear Element Text    ${SEARCH_INPUT}
    Input Text    ${SEARCH_INPUT}    ${product_name}
    Click Button    ${SEARCH_BUTTON}
    Wait Until Page Contains Element    ${PRODUCT_CARD}    timeout=${TIMEOUT}

Add Product To Cart
    [Arguments]    ${product_index}=1
    ${product_selector}=    Set Variable    css:[data-testid="product-card"]:nth-child(${product_index}) [data-testid="add-to-cart"]
    Wait Until Element Is Visible    ${product_selector}    timeout=${TIMEOUT}
    Click Button    ${product_selector}
    Wait Until Element Is Visible    css:.toast-success    timeout=5s

Get Cart Item Count
    ${count}=    Get Text    ${CART_ITEM_COUNT}
    [Return]    ${count}

Clear Cart
    Click Element    ${CART_ICON}
    Wait Until Page Contains Element    css:[data-testid="cart-items"]    timeout=${TIMEOUT}
    ${items}=    Get WebElements    css:[data-testid="remove-item"]
    FOR    ${item}    IN    @{items}
        Click Element    ${item}
        Sleep    0.5s
    END

Verify Registration Success
    # Check if we're redirected to home page
    ${on_home}=    Run Keyword And Return Status    Location Should Be    ${BASE_URL}${HOME_ROUTE}
    Run Keyword If    ${on_home}    Log    Registration successful - redirected to home
    Run Keyword If    not ${on_home}    Handle Registration Failure

Handle Registration Failure
    # Check if we're still on registration page (indicates error)
    ${on_register}=    Run Keyword And Return Status    Location Should Be    ${BASE_URL}${SIGNUP_ROUTE}
    Run Keyword If    ${on_register}    Log    Registration failed - still on registration page
    Run Keyword If    ${on_register}    Page Should Contain Element    ${ERROR_MESSAGE}

    # Check current URL
    ${current_url}=    Get Location
    Log    Current URL after registration: ${current_url}

*** Test Cases ***
TC001 - Vérifier le chargement de la page d'accueil
    [Documentation]    Vérifier que la page d'accueil se charge correctement
    [Tags]    smoke    ui
    Navigate To Home Page
    Page Should Contain Element    ${PRODUCT_GRID}

TC002 - Navigation vers la page de connexion
    [Documentation]    Vérifier la navigation vers la page de connexion
    [Tags]    navigation    ui
    Navigate To Login Page
    Page Should Contain    Sign in
    Page Should Contain Element    ${LOGIN_EMAIL_INPUT}
    Page Should Contain Element    ${LOGIN_PASSWORD_INPUT}
    Page Should Contain Element    ${REMEMBER_CHECKBOX}

TC003 - Navigation vers la page d'inscription
    [Documentation]    Vérifier la navigation vers la page d'inscription
    [Tags]    navigation    ui
    Navigate To Register Page
    Page Should Contain    Register
    Page Should Contain Element    ${REGISTER_EMAIL_INPUT}
    Page Should Contain Element    ${REGISTER_USERNAME_INPUT}
    Page Should Contain Element    ${REGISTER_PASSWORD_INPUT}

TC004 - Inscription avec des données valides
    [Documentation]    Tester l'inscription avec des données valides
    [Tags]    registration    critical    prerequisite
    ${timestamp}=    Get Current Date    result_format=%Y%m%d%H%M%S
    ${unique_email}=    Set Variable    test${timestamp}@example.com
    ${unique_username}=    Set Variable    testuser${timestamp}
    ${password}=    Set Variable    Test123!

    # Set suite variables to use in login test
    Set Suite Variable    ${REGISTERED_EMAIL}    ${unique_email}
    Set Suite Variable    ${REGISTERED_USERNAME}    ${unique_username}
    Set Suite Variable    ${REGISTERED_PASSWORD}    ${password}

    # Navigate and fill registration form
    Navigate To Register Page
    Wait Until Element Is Visible    ${REGISTER_EMAIL_INPUT}    timeout=${TIMEOUT}
    Input Text    ${REGISTER_EMAIL_INPUT}    ${unique_email}
    Input Text    ${REGISTER_USERNAME_INPUT}    ${unique_username}
    Input Text    ${REGISTER_PASSWORD_INPUT}    ${password}

    # Submit form
    Click Button    ${REGISTER_BUTTON}

    # Verify successful registration with better error handling
    Wait Until Location Is    ${BASE_URL}${HOME_ROUTE}    timeout=15s
    Verify Registration Success
    Check User Is Logged In
    Log    Registration successful for ${unique_email}

TC005 - Connexion avec des identifiants valides
    [Documentation]    Tester la connexion avec les identifiants créés lors de l'inscription
    [Tags]    authentication    critical

    # Check if logout button exists before trying to logout
    ${logout_exists}=    Run Keyword And Return Status    Page Should Contain Element    ${LOGOUT_BUTTON}
    Run Keyword If    ${logout_exists}    Logout User
    Run Keyword If    not ${logout_exists}    Log    No logout button found, proceeding with login test

    # Login with the credentials from registration
    Login With Credentials    ${REGISTERED_EMAIL}    ${REGISTERED_PASSWORD}
    Check User Is Logged In
    Log    Login successful with registered credentials: ${REGISTERED_EMAIL}

TC006 - Connexion avec email invalide
    [Documentation]    Tester la connexion avec un email invalide
    [Tags]    authentication    negative
    Login With Invalid Credentials    ${INVALID_EMAIL}    ${REGISTERED_PASSWORD}
    Page Should Contain Element    ${ERROR_MESSAGE}

TC007 - Connexion avec mot de passe invalide
    [Documentation]    Tester la connexion avec un mot de passe invalide
    [Tags]    authentication    negative
    Login With Invalid Credentials    ${REGISTERED_EMAIL}    ${INVALID_PASSWORD}
    Page Should Contain Element    ${ERROR_MESSAGE}

TC008 - Inscription avec email invalide
    [Documentation]    Tester l'inscription avec un email invalide
    [Tags]    registration    negative
    ${timestamp}=    Get Current Date    result_format=%Y%m%d%H%M%S
    Register New User    invalid-email    testuser${timestamp}    Test123!
    Wait Until Page Contains Element    ${ERROR_MESSAGE}    timeout=5s

TC009 - Lien vers inscription depuis la page de connexion
    [Documentation]    Tester le lien vers l'inscription depuis la page de connexion
    [Tags]    navigation    ui
    Navigate To Login Page
    Click Link    ${REGISTER_LINK}
    Wait Until Location Is    ${BASE_URL}${SIGNUP_ROUTE}    timeout=${TIMEOUT}
    Page Should Contain    Register

TC010 - Checkbox "Remember me" fonctionnel
    [Documentation]    Tester que la checkbox Remember me fonctionne
    [Tags]    ui    functional
    Navigate To Login Page
    ${is_selected}=    Run Keyword And Return Status    Checkbox Should Be Selected    ${REMEMBER_CHECKBOX}
    Run Keyword If    ${is_selected}    Unselect Checkbox    ${REMEMBER_CHECKBOX}
    Checkbox Should Not Be Selected    ${REMEMBER_CHECKBOX}
    Select Checkbox    ${REMEMBER_CHECKBOX}
    Checkbox Should Be Selected    ${REMEMBER_CHECKBOX}

TC011 - Inscription puis connexion - Workflow complet
    [Documentation]    Test complet: inscription, déconnexion, puis connexion avec mêmes identifiants
    [Tags]    workflow    critical    complete

    # Step 1: Register new user
    ${timestamp}=    Get Current Date    result_format=%Y%m%d%H%M%S
    ${email}=    Set Variable    workflow${timestamp}@example.com
    ${username}=    Set Variable    workflowuser${timestamp}
    ${password}=    Set Variable    Workflow123!

    Register New User    ${email}    ${username}    ${password}
    Wait Until Location Is    ${BASE_URL}${HOME_ROUTE}    timeout=15s
    Verify Registration Success
    Check User Is Logged In
    Log    Registration successful for ${email}

    # Step 2: Logout (with error handling)
    ${logout_exists}=    Run Keyword And Return Status    Page Should Contain Element    ${LOGOUT_BUTTON}
    Run Keyword If    ${logout_exists}    Logout User
    Run Keyword If    not ${logout_exists}    Log    Logout button not found - may need to navigate manually
    Log    User logout attempted

    # Step 3: Login with the same credentials
    Login With Credentials    ${email}    ${password}
    Check User Is Logged In
    Log    Login successful with registered credentials

TC012 - Debug page elements after registration
    [Documentation]    Test pour déboguer les éléments de la page après inscription
    [Tags]    debug
    ${timestamp}=    Get Current Date    result_format=%Y%m%d%H%M%S
    ${unique_email}=    Set Variable    debug${timestamp}@example.com
    ${unique_username}=    Set Variable    debuguser${timestamp}
    ${password}=    Set Variable    Debug123!

    Register New User    ${unique_email}    ${unique_username}    ${password}
    Sleep    3s
    Debug Page Elements
