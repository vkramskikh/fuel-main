class nailytest {
        case $role {
                "controller" : {
                        include nailytest::test_controller
                }
        }

        case $role {
                "compute" : {
                        include nailytest::test_compute
                }
        }       

        include nailytest::network_setup

}
